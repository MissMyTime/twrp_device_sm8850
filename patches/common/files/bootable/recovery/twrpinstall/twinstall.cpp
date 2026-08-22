/*
	Copyright 2012 to 2017 bigbiff/Dees_Troy TeamWin
	This file is part of TWRP/TeamWin Recovery Project.

	TWRP is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	TWRP is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with TWRP.  If not, see <http://www.gnu.org/licenses/>.
*/


#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include <string.h>
#include <stdio.h>
#include <cutils/properties.h>

#include <android-base/unique_fd.h>

#include "twcommon.h"
#include "mtdutils/mounts.h"
#include "mtdutils/mtdutils.h"

#include "otautil/sysutil.h"
#include <ziparchive/zip_archive.h>
#include <fstream>
#include "twinstall/install.h"
#include "twinstall/verifier.h"
#include "variables.h"
#include "data.hpp"
#include "partitions.hpp"
#include "twrpDigestDriver.hpp"
#include "twrpDigest/twrpDigest.hpp"
#include "twrpDigest/twrpMD5.hpp"
#include "twrp-functions.hpp"
#include "gui/gui.hpp"
#include "gui/pages.hpp"
#include "twinstall.h"
#include "installcommand.h"
#include "../twrpRepacker.hpp"
extern "C" {
	#include "gui/gui.h"
}

#define AB_OTA "payload_properties.txt"

enum zip_type {
	UNKNOWN_ZIP_TYPE = 0,
	UPDATE_BINARY_ZIP_TYPE,
	AB_OTA_ZIP_TYPE,
	TWRP_THEME_ZIP_TYPE
};

static bool EnsureInstallerCompatibilityLink(const char* target, const char* link_path) {
	struct stat st;
	if (access(link_path, X_OK) == 0)
		return true;

	if (lstat(link_path, &st) == 0) {
		if (!S_ISLNK(st.st_mode)) {
			LOGERR("Installer compatibility path '%s' exists but is not executable.\n", link_path);
			return false;
		}
		unlink(link_path);
	}

	if (access(target, X_OK) != 0 || symlink(target, link_path) != 0) {
		LOGERR("Unable to create installer compatibility link %s -> %s: %s\n",
		       link_path, target, strerror(errno));
		return false;
	}

	LOGINFO("Created installer compatibility link %s -> %s\n", link_path, target);
	return true;
}

static bool EnsureInstallerCompatibilityPaths() {
	return EnsureInstallerCompatibilityLink("/system/bin/sh", "/sbin/sh") &&
	       EnsureInstallerCompatibilityLink("/system/bin/bash", "/sbin/bash") &&
	       EnsureInstallerCompatibilityLink("/system/bin/bash", "/sbin/bas") &&
	       EnsureInstallerCompatibilityLink("/system/bin/getprop", "/sbin/getprop");
}

static std::string GetInstallerActiveSlotSuffix() {
	std::string slot = PartitionManager.Get_Active_Slot_Suffix();
	char prop[PROP_VALUE_MAX] = { 0 };

	if (slot != "_a" && slot != "_b") {
		property_get("ro.boot.slot_suffix", prop, "");
		slot = prop;
		if (slot == "a" || slot == "b")
			slot.insert(0, "_");
	}

	if (slot != "_a" && slot != "_b") {
		memset(prop, 0, sizeof(prop));
		property_get("ro.boot.slot", prop, "");
		slot = prop;
		if (slot == "a" || slot == "b")
			slot.insert(0, "_");
	}

	if (slot != "_a" && slot != "_b")
		slot.clear();

	return slot;
}

static int Install_Theme(const char* path, ZipArchiveHandle Zip) {
#ifdef TW_OEM_BUILD // We don't do custom themes in OEM builds
	return INSTALL_CORRUPT;
#else
	std::string binary_name("ui.xml");
	ZipEntry64 binary_entry;
	if (FindEntry(Zip, binary_name, &binary_entry) != 0) {
		return INSTALL_CORRUPT;
	}
	if (!PartitionManager.Mount_Settings_Storage(true))
		return INSTALL_ERROR;
	string theme_path = DataManager::GetSettingsStoragePath();
	theme_path += "/TWRP/theme";
	if (!TWFunc::Path_Exists(theme_path)) {
		if (!TWFunc::Recursive_Mkdir(theme_path)) {
			return INSTALL_ERROR;
		}
	}
	theme_path += "/ui.zip";
	if (TWFunc::copy_file(path, theme_path, 0644) != 0) {
		return INSTALL_ERROR;
	}
	LOGINFO("Installing custom theme '%s' to '%s'\n", path, theme_path.c_str());
	PageManager::RequestReload();
	return INSTALL_SUCCESS;
#endif
}

static int Prepare_Update_Binary(ZipArchiveHandle Zip) {
	char arches[PATH_MAX];
	property_get("ro.product.cpu.abilist", arches, "error");
	if (strcmp(arches, "error") == 0)
		property_get("ro.product.cpu.abi", arches, "error");
	vector<string> split = TWFunc::split_string(arches, ',', true);
	std::vector<string>::iterator arch;
	std::string base_name = UPDATE_BINARY_NAME;
	base_name += "-";
	ZipEntry64 binary_entry;
	std::string update_binary_string(UPDATE_BINARY_NAME);
	if (FindEntry(Zip, update_binary_string, &binary_entry) != 0) {
		for (arch = split.begin(); arch != split.end(); arch++) {
			std::string temp = base_name + *arch;
			std::string binary_name(temp.c_str());
			if (FindEntry(Zip, binary_name, &binary_entry) != 0) {
				std::string binary_name(temp.c_str());
				break;
			}
		}
	}
	LOGINFO("Extracting updater binary '%s'\n", UPDATE_BINARY_NAME);
	unlink(TMP_UPDATER_BINARY_PATH);
	android::base::unique_fd fd(
		open(TMP_UPDATER_BINARY_PATH, O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, 0755));
	if (fd == -1) {
		return INSTALL_ERROR;
	}
	int32_t err = ExtractEntryToFile(Zip, &binary_entry, fd);
	if (err != 0) {
		LOGERR("Could not extract '%s'\n", UPDATE_BINARY_NAME);
		return INSTALL_ERROR;
	}

	// Keep recovery tools available to legacy shell installers. AnyKernel3 creates
	// its own BusyBox tree later, so its getprop compatibility hook is injected
	// after that tree is populated.
	{
		std::ifstream infile(TMP_UPDATER_BINARY_PATH);
		std::string script((std::istreambuf_iterator<char>(infile)),
							std::istreambuf_iterator<char>());
		infile.close();
		bool modified = false;
		if (script.find("TWRP_RECOVERY_PATH_COMPAT") == std::string::npos) {
			std::string shebang;
			if (script.length() > 2 && script[0] == '#' && script[1] == '!') {
				size_t nl = script.find('\n');
				if (nl != std::string::npos) {
					shebang = script.substr(0, nl + 1);
					script = script.substr(nl + 1);
				}
			}
			script = shebang +
				"# TWRP_RECOVERY_PATH_COMPAT\n"
				"export PATH=\"/tmp:/sbin:$PATH\"\n" + script;
			modified = true;
		}

		const std::string ak3_setup_marker = "setup_env;";
		const bool is_anykernel3 =
			script.find("AnyKernel3") != std::string::npos &&
			script.find(ak3_setup_marker) != std::string::npos &&
			script.find("anykernel.sh") != std::string::npos;
		if (is_anykernel3 &&
				script.find("TWRP_AK3_POST_SETUP_SLOT_COMPAT") == std::string::npos) {
			size_t marker = script.find(ak3_setup_marker);
			if (marker != std::string::npos) {
				marker += ak3_setup_marker.length();
				const std::string active_slot = GetInstallerActiveSlotSuffix();
				const std::string slot_hook =
					"\n# TWRP_AK3_POST_SETUP_SLOT_COMPAT\n"
					"TWRP_AK3_SLOT=\"" + active_slot + "\"\n"
					"if [ \"$TWRP_AK3_SLOT\" != \"_a\" ] && [ \"$TWRP_AK3_SLOT\" != \"_b\" ]; then\n"
					"  TWRP_AK3_SLOT=\"$(/tmp/getprop ro.boot.slot_suffix 2>/dev/null)\"\n"
					"fi\n"
					"case \"$TWRP_AK3_SLOT\" in\n"
					"  _a|_b) ;;\n"
					"  *) TWRP_AK3_SLOT=\"\" ;;\n"
					"esac\n"
					"if [ \"$TWRP_AK3_SLOT\" ] && [ -f \"$AKHOME/tools/ak3-core.sh\" ]; then\n"
					"  awk -v slot=\"$TWRP_AK3_SLOT\" '\n"
					"    index($0, \"SLOT=$(getprop ro.boot.slot_suffix\") {\n"
					"      print \"      SLOT=\\\"\" slot \"\\\"; # TWRP_AK3_SLOT_FIXED\";\n"
					"      next;\n"
					"    }\n"
					"    { print }\n"
					"  ' \"$AKHOME/tools/ak3-core.sh\" > \"$AKHOME/tools/ak3-core.sh.twrp\"\n"
					"  if grep -q 'TWRP_AK3_SLOT_FIXED' \"$AKHOME/tools/ak3-core.sh.twrp\"; then\n"
					"    mv -f \"$AKHOME/tools/ak3-core.sh.twrp\" \"$AKHOME/tools/ak3-core.sh\"\n"
					"    ui_print \"AK3 active slot fixed: $TWRP_AK3_SLOT\"\n"
					"  else\n"
					"    rm -f \"$AKHOME/tools/ak3-core.sh.twrp\"\n"
					"    ui_print \"Warning: unsupported AK3 slot detection layout\"\n"
					"  fi\n"
					"fi\n"
					"ui_print \"TWRP active slot: $TWRP_AK3_SLOT\"\n";
				const std::string volkey_hook = R"AK3(
# TWRP_AK3_POST_SETUP_VOLKEY_COMPAT
if [ -f "$AKHOME/anykernel.sh" ] &&
   grep -q 'timeout 0\.1 getevent -qlc 1' "$AKHOME/anykernel.sh" &&
   ! grep -q 'TWRP_AK3_VOLKEY_FIXED' "$AKHOME/anykernel.sh"; then
  awk '
    BEGIN { replacing = 0 }
    /^[[:space:]]*choose_with_volkey\(\)[[:space:]]*\{/ {
      print "# TWRP_AK3_VOLKEY_FIXED"
      print "choose_with_volkey() {"
      print "  local key i=0"
      print "  rm -f /tmp/twrp-ak3-volkey /tmp/twrp-ak3-volkey.pending"
      print "  echo 1 > /tmp/twrp-ak3-volkey-arm"
      print "  while [ \"$i\" -lt 100 ]; do"
      print "    if [ -s /tmp/twrp-ak3-volkey ]; then"
      print "      IFS= read -r key < /tmp/twrp-ak3-volkey"
      print "      rm -f /tmp/twrp-ak3-volkey-arm /tmp/twrp-ak3-volkey"
      print "      case \"$key\" in"
      print "        KEY_VOLUMEUP|KEY_VOLUMEDOWN)"
      print "          echo \"TWRP_AK3_VOLKEY=$key\" >&2"
      print "          echo \"$key\""
      print "          return"
      print "          ;;"
      print "      esac"
      print "    fi"
      print "    sleep 0.1"
      print "    i=$((i + 1))"
      print "  done"
      print "  rm -f /tmp/twrp-ak3-volkey-arm /tmp/twrp-ak3-volkey"
      print "  echo timeout"
      print "}"
      replacing = 1
      next
    }
    replacing {
      if ($0 ~ /^[[:space:]]*}[[:space:]]*$/) replacing = 0
      next
    }
    { print }
  ' "$AKHOME/anykernel.sh" > "$AKHOME/anykernel.sh.twrp"
  if grep -q 'TWRP_AK3_VOLKEY_FIXED' "$AKHOME/anykernel.sh.twrp"; then
    mv -f "$AKHOME/anykernel.sh.twrp" "$AKHOME/anykernel.sh"
    chmod 0755 "$AKHOME/anykernel.sh"
    ui_print "AK3 volume-key detection fixed by TWRP (v4)"
  else
    rm -f "$AKHOME/anykernel.sh.twrp"
    ui_print "Warning: unsupported AK3 volume-key layout"
  fi
fi
)AK3";
				script.insert(marker, slot_hook + volkey_hook);
				modified = true;
				LOGINFO("Injected AnyKernel3 core slot fix (slot=%s)\n",
						active_slot.c_str());
				LOGINFO("Injected AnyKernel3 volume-key compatibility hook\n");
			} else {
				LOGINFO("AnyKernel3 updater found without the expected setup_env marker\n");
			}
		}

		if (modified) {
			std::ofstream outfile(TMP_UPDATER_BINARY_PATH);
			outfile << script;
			outfile.close();
			chmod(TMP_UPDATER_BINARY_PATH, 0755);
		}
	}

	// If exists, extract file_contexts from the zip file
	std::string file_contexts("file_contexts");
	ZipEntry64 file_contexts_entry;
	if (FindEntry(Zip, file_contexts, &file_contexts_entry) != 0) {
		LOGINFO("Zip does not contain SELinux file_contexts file in its root.\n");
	} else {
		const string output_filename = "/file_contexts";
		LOGINFO("Zip contains SELinux file_contexts file in its root. Extracting to %s\n", output_filename.c_str());
		android::base::unique_fd fd(
			open(output_filename.c_str(), O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, 0644));
		if (fd == -1) {
			return INSTALL_ERROR;
		}
		if (ExtractEntryToFile(Zip, &file_contexts_entry, fd)) {
			LOGERR("Could not extract '%s'\n", output_filename.c_str());
			return INSTALL_ERROR;
		}
	}
	return INSTALL_SUCCESS;
}


static int Run_Update_Binary(const char *path, int* wipe_cache, zip_type ztype) {
	int ret_val, pipe_fd[2], status, zip_verify;
	char buffer[1024];
	FILE* child_data;
	pipe(pipe_fd);

	std::vector<std::string> args;
    if (ztype == UPDATE_BINARY_ZIP_TYPE) {
		ret_val = update_binary_command(path, 0, pipe_fd[1], &args);
    } else if (ztype == AB_OTA_ZIP_TYPE) {
		ret_val = abupdate_binary_command(path, 0, pipe_fd[1], &args);
	} else {
		LOGERR("Unknown zip type %i\n", ztype);
		ret_val = INSTALL_CORRUPT;
	}
	if (ret_val) {
		close(pipe_fd[0]);
		close(pipe_fd[1]);
		return ret_val;
	}

	if (!EnsureInstallerCompatibilityPaths()) {
		gui_err("installer_compat_paths=Required installer shell/getprop compatibility paths are unavailable.");
		close(pipe_fd[0]);
		close(pipe_fd[1]);
		return INSTALL_ERROR;
	}

	// Convert the vector to a NULL-terminated char* array suitable for execv.
	const char* chr_args[args.size() + 1];
	chr_args[args.size()] = NULL;
	for (size_t i = 0; i < args.size(); i++)
		chr_args[i] = args[i].c_str();

	pid_t pid = fork();
	if (pid == 0) {
		close(pipe_fd[0]);
		// AK3 detects slots via getprop, not bootctl. When the system partition is
		// mounted, /system/bin/getprop may crash due to library version mismatch.
		// Create a /tmp/getprop wrapper that hardcodes the slot values and falls
		// back to /sbin/getprop for all other properties.
		char slot_suffix[PROP_VALUE_MAX] = {0};
		property_get("ro.boot.slot_suffix", slot_suffix, "");
		if (slot_suffix[0] == '\0')
			property_get("ro.boot.slot", slot_suffix, "");
		std::string slot_val = slot_suffix;
		if (slot_val.empty()) slot_val = "_a";
		if (slot_val[0] != '_') slot_val = "_" + slot_val;
		std::string slot_short = slot_val.substr(1); // a or b

		FILE* f = fopen("/tmp/getprop", "w");
		if (f) {
			fprintf(f, "#!/sbin/sh\n");
			fprintf(f, "if [ -z \"$1\" ]; then\n");
			fprintf(f, "    echo \"[getprop.wrapper]: listing properties...\"\n");
			fprintf(f, "    /sbin/getprop 2>/dev/null\n");
			fprintf(f, "    exit 0\n");
			fprintf(f, "fi\n");
			fprintf(f, "case \"$1\" in\n");
			fprintf(f, "    ro.boot.slot_suffix) echo \"%s\" ;;\n", slot_val.c_str());
			fprintf(f, "    ro.boot.slot) echo \"%s\" ;;\n", slot_short.c_str());
			fprintf(f, "    *) /sbin/getprop \"$1\" 2>/dev/null ;;\n");
			fprintf(f, "esac\n");
			fprintf(f, "exit 0\n");
			fclose(f);
			chmod("/tmp/getprop", 0755);
			LOGINFO("Created /tmp/getprop wrapper for AK3 slot detection (slot=%s)\n", slot_val.c_str());
		}
		// Also create bootctl wrapper for any other installers that use it.
		// Some legacy ROM zips call bootctl from update-binary to switch slots.
		// Defer that state change: the GUI worker applies it only after the
		// installer exits successfully, so a failed package cannot arm a bad slot.
		f = fopen("/tmp/bootctl", "w");
			if (f) {
				fprintf(f, "#!/sbin/sh\n");
				fprintf(f, "record_slot() {\n");
				fprintf(f, "    case \"$1\" in\n");
				fprintf(f, "        0|a|A|_a|_A) echo A > /tmp/twrp_requested_slot; echo 0 ;;\n");
				fprintf(f, "        1|b|B|_b|_B) echo B > /tmp/twrp_requested_slot; echo 0 ;;\n");
				fprintf(f, "        *) echo 0 ;;\n");
				fprintf(f, "    esac\n");
				fprintf(f, "}\n");
				fprintf(f, "if [ -z \"$1\" ]; then\n");
				fprintf(f, "    /sbin/bootctl 2>/dev/null || true\n");
				fprintf(f, "    exit 0\n");
				fprintf(f, "fi\n");
				fprintf(f, "case \"$1\" in\n");
				fprintf(f, "    get-current-slot)\n");
				fprintf(f, "        case \"%s\" in _a|a) echo 0 ;; _b|b) echo 1 ;; *) echo 0 ;; esac\n", slot_val.c_str());
				fprintf(f, "        ;;\n");
				fprintf(f, "    get-suffix)\n");
				fprintf(f, "        case \"$2\" in 0) echo \"_a\" ;; 1) echo \"_b\" ;; \"\") echo \"%s\" ;; *) echo \"_a\" ;; esac\n", slot_val.c_str());
				fprintf(f, "        ;;\n");
				fprintf(f, "    get-number-slots)\n");
				fprintf(f, "        echo 2\n");
				fprintf(f, "        ;;\n");
				fprintf(f, "    set-active-boot-slot|set_active_boot_slot|set-active-slot|set_active_slot|set-active|set_active|set-current-slot|set_current_slot)\n");
				fprintf(f, "        record_slot \"$2\"\n");
				fprintf(f, "        ;;\n");
				fprintf(f, "    is-slot-bootable|is-slot-marked-successful|mark-boot-successful)\n");
				fprintf(f, "        /sbin/bootctl \"$@\" 2>/dev/null || true\n");
				fprintf(f, "        ;;\n");
				fprintf(f, "    *)\n");
				fprintf(f, "        /sbin/bootctl \"$@\" 2>/dev/null || true\n");
				fprintf(f, "        ;;\n");
				fprintf(f, "esac\n");
				fprintf(f, "exit 0\n");
				fclose(f);
				chmod("/tmp/bootctl", 0755);
			}
		// Ensure /sbin/bootctl also exists as fallback
		chmod("/sbin/bootctl", 0755);
		// Prioritize /tmp and /sbin in PATH before system paths
		setenv("PATH", "/tmp:/sbin:/system/bin:/system/xbin:/vendor/bin:/vendor_xbin", 1);
		execve(chr_args[0], const_cast<char**>(chr_args), environ);
		printf("E:Can't execute '%s': %s\n", chr_args[0], strerror(errno));
		_exit(-1);
	}
	close(pipe_fd[1]);

	*wipe_cache = 0;

	DataManager::GetValue(TW_SIGNED_ZIP_VERIFY_VAR, zip_verify);
	child_data = fdopen(pipe_fd[0], "r");
	while (fgets(buffer, sizeof(buffer), child_data) != NULL) {
		char* command = strtok(buffer, " \n");
		if (command == NULL) {
			continue;
		} else if (strcmp(command, "progress") == 0) {
			char* fraction_char = strtok(NULL, " \n");
			char* seconds_char = strtok(NULL, " \n");

			float fraction_float = strtof(fraction_char, NULL);
			int seconds_float = strtol(seconds_char, NULL, 10);

			if (zip_verify)
				DataManager::ShowProgress(fraction_float * (1 - VERIFICATION_PROGRESS_FRACTION), seconds_float);
			else
				DataManager::ShowProgress(fraction_float, seconds_float);
		} else if (strcmp(command, "set_progress") == 0) {
			char* fraction_char = strtok(NULL, " \n");
			float fraction_float = strtof(fraction_char, NULL);
			DataManager::_SetProgress(fraction_float);
		} else if (strcmp(command, "ui_print") == 0) {
			char* display_value = strtok(NULL, "\n");
			if (display_value) {
				gui_print("%s", display_value);
			} else {
				gui_print("\n");
			}
		} else if (strcmp(command, "wipe_cache") == 0) {
			*wipe_cache = 1;
		} else if (strcmp(command, "clear_display") == 0) {
			// Do nothing, not supported by TWRP
		} else if (strcmp(command, "log") == 0) {
			printf("%s\n", strtok(NULL, "\n"));
		} else {
			LOGERR("unknown command [%s]\n", command);
		}
	}
	fclose(child_data);

	int waitrc = TWFunc::Wait_For_Child(pid, &status, "Updater");
	if (waitrc != 0)
		return INSTALL_ERROR;

	return INSTALL_SUCCESS;
}

static constexpr const char* UPDATE_DYNAMIC_PART_OP_LIST_NAME = "dynamic_partitions_op_list";
static constexpr const char* UPDATE_SUPER_IMAGE_ZST = "super.img.zst";
static constexpr const char* UPDATE_SUPER_ZST = "super.zst";

bool isUpdatePkg(ZipArchiveHandle Zip) {
	ZipEntry64 find_entry;
	if (FindEntry(Zip, UPDATE_DYNAMIC_PART_OP_LIST_NAME, &find_entry) == 0) return true;
	if (FindEntry(Zip, UPDATE_SUPER_IMAGE_ZST, &find_entry) == 0) return true;
	if (FindEntry(Zip, UPDATE_SUPER_ZST, &find_entry) == 0) return true;
	if (FindEntry(Zip, AB_OTA, &find_entry) == 0) return true;
	return false;
}

int TWinstall_zip(const char* path, int* wipe_cache, bool check_for_digest) {
	int ret_val, zip_verify = 1, unmount_system = 1, reflashtwrp = 0;

	DataManager::SetValue("tw_zip_is_update_package", 0);
	gui_msg(Msg("installing_zip=Installing zip file '{1}'")(path));
	if (strlen(path) < 9 || strncmp(path, "/sideload", 9) != 0) {
		string digest_str;
		string Full_Filename = path;

		if (check_for_digest) {
			gui_msg("check_for_digest=Checking for Digest file...");
			if (*path != '@' && !twrpDigestDriver::Check_File_Digest(Full_Filename)) {
				LOGERR("Aborting zip install: Digest verification failed\n");
				return INSTALL_CORRUPT;
			}
		}
	}

	DataManager::GetValue(TW_UNMOUNT_SYSTEM, unmount_system);

#ifndef TW_OEM_BUILD
	DataManager::GetValue(TW_SIGNED_ZIP_VERIFY_VAR, zip_verify);
#endif
	DataManager::SetProgress(0);

	auto package = Package::CreateMemoryPackage(path);
	if (!package) {
		return INSTALL_CORRUPT;
	}

	if (zip_verify) {
		gui_msg("verify_zip_sig=Verifying zip signature...");
		static constexpr const char* CERTIFICATE_ZIP_FILE = "/system/etc/security/otacerts.zip";
		std::vector<Certificate> loaded_keys = LoadKeysFromZipfile(CERTIFICATE_ZIP_FILE);
		if (loaded_keys.empty()) {
			LOGERR("Failed to load keys\n");
			return -1;
		}
		LOGINFO("%zu key(s) loaded from %s\n", loaded_keys.size(), CERTIFICATE_ZIP_FILE);

		ret_val = verify_file(package.get(), loaded_keys, std::bind(&DataManager::SetProgress, std::placeholders::_1));
		if (ret_val != VERIFY_SUCCESS) {
			LOGINFO("Zip signature verification failed: %i\n", ret_val);
			gui_err("verify_zip_fail=Zip signature verification failed!");
#ifdef USE_MINZIP
			sysReleaseMap(&map);
#endif
			return -1;
		} else {
			gui_msg("verify_zip_done=Zip signature verified successfully.");
		}
	}

	ZipArchiveHandle Zip = package->GetZipArchiveHandle();
	if (!Zip) {
		return INSTALL_CORRUPT;
	}

	bool _isUpdatePkg = isUpdatePkg(Zip), _isABUpdatePkg = false;
	DataManager::SetValue("tw_zip_is_update_package", _isUpdatePkg ? 1 : 0);

	if (_isUpdatePkg && !PartitionManager.Repair_Super_Metadata_Size(true)) {
		gui_err("super_repair_pre_install=Unable to verify or repair logical partition capacity before installing the update.");
		return INSTALL_ERROR;
	}

	if (unmount_system) {
		gui_msg("unmount_system=Unmounting System...");
		if(!PartitionManager.UnMount_By_Path(PartitionManager.Get_Android_Root_Path(), true)) {
			gui_err("unmount_system_err=Failed unmounting System");
			return -1;
		}
		unlink("/system");
		mkdir("/system", 0755);
	}

	time_t start, stop;
	time(&start);

	std::string update_binary_name(UPDATE_BINARY_NAME);
	ZipEntry64 update_binary_entry;
	if (FindEntry(Zip, update_binary_name, &update_binary_entry) == 0) {
		LOGINFO("Update binary zip\n");
		// Additionally verify the compatibility of the package.
		if (!verify_package_compatibility(Zip)) {
			gui_err("zip_compatible_err=Zip Treble compatibility error!");
			ret_val = INSTALL_CORRUPT;
		} else {
			ret_val = Prepare_Update_Binary(Zip);
			if (ret_val == INSTALL_SUCCESS)
				ret_val = Run_Update_Binary(path, wipe_cache, UPDATE_BINARY_ZIP_TYPE);
		}
	} else {
		std::string ab_binary_name(AB_OTA);
		ZipEntry64 ab_binary_entry;
		if (FindEntry(Zip, ab_binary_name, &ab_binary_entry) == 0) {
			LOGINFO("AB zip\n");
			_isABUpdatePkg = true;
			gui_msg(Msg(msg::kHighlight, "flash_ab_inactive=Flashing A/B zip to inactive slot: {1}")(PartitionManager.Get_Active_Slot_Display()=="A"?"B":"A"));
			// We need this so backuptool can do its magic
			bool system_mount_state = PartitionManager.Is_Mounted_By_Path(PartitionManager.Get_Android_Root_Path());
			bool vendor_mount_state = PartitionManager.Is_Mounted_By_Path("/vendor");
			PartitionManager.Mount_By_Path(PartitionManager.Get_Android_Root_Path(), false);
			PartitionManager.Mount_By_Path("/vendor", false);
			TWFunc::copy_file("/system/bin/sh", "/tmp/sh", 0755);
			mount("/tmp/sh", "/system/bin/sh", "auto", MS_BIND, NULL);
			ret_val = Run_Update_Binary(path, wipe_cache, AB_OTA_ZIP_TYPE);
			umount("/system/bin/sh");
			unlink("/tmp/sh");
			if (!vendor_mount_state)
				PartitionManager.UnMount_By_Path("/vendor", false);
			if (!system_mount_state)
				PartitionManager.UnMount_By_Path(PartitionManager.Get_Android_Root_Path(), false);
			if (ret_val == INSTALL_SUCCESS) {
				if (android::base::GetBoolProperty("ro.virtual_ab.enabled", false)) {
					PartitionManager.Unlock_Block_Partitions();
					PartitionManager.Prepare_All_Super_Volumes();
					gui_warn("mount_vab_partitions=Devices on super may not mount until rebooting recovery.");
				}
				gui_warn("flash_ab_reboot=To flash additional zips, please reboot recovery to switch to the updated slot.");
				DataManager::GetValue(TW_AUTO_REFLASHTWRP_VAR, reflashtwrp);
				if (reflashtwrp &&
						!TWFunc::Path_Exists("/dev/block/bootdevice/by-name/recovery_a")) {
					twrpRepacker repacker;
					repacker.Flash_Current_Twrp();
				}
			}
		} else {
			std::string binary_name("ui.xml");
			ZipEntry64 binary_entry;
			if (FindEntry(Zip, binary_name, &binary_entry) == 0) {
				LOGINFO("TWRP theme zip\n");
				ret_val = Install_Theme(path, Zip);
			} else {
				ret_val = INSTALL_CORRUPT;
			}
		}
	}
	time(&stop);
	int total_time = (int) difftime(stop, start);
	if (ret_val == INSTALL_CORRUPT) {
		gui_err("invalid_zip_format=Invalid zip file format!");
	} else {
		LOGINFO("Install took %i second(s).\n", total_time);
	}

	if (ret_val == INSTALL_SUCCESS) gui_msg(Msg(msg::kHighlight, "install_took_seconds_msg=Install took {1} second(s).")(total_time));

	if (_isUpdatePkg && ret_val == INSTALL_SUCCESS &&
	    !PartitionManager.Repair_Super_Metadata_Size(true)) {
		gui_err("super_repair_post_install=The update completed, but logical partition capacity verification failed.");
		ret_val = INSTALL_ERROR;
	}

	if (_isUpdatePkg && ret_val == INSTALL_SUCCESS) {
		if (DataManager::GetIntValue(TW_AUTO_DISABLE_AVB2_VAR)) PartitionManager.Disable_AVB2(true);
	}

	return ret_val;
}
