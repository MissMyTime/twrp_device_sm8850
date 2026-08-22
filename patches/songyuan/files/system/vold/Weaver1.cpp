/*
 * Copyright (C) 2017 Team Win Recovery Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* To the best of my knowledge there is no native implementation for
 * Weaver so I made this by looking at the IWeaver.h file that gets
 * compiled by the build system. I took the information from this header
 * file and looked at keymaster source to get an idea of the proper way
 * to write the functions.
 */

#include "Weaver1.h"

//#include <android-base/logging.h>
//#include <keystore/keymaster_tags.h>
//#include <keystore/authorization_set.h>
//#include <keystore/keystore_hidl_support.h>

#include <android/binder_manager.h>

#include <android/hardware/weaver/1.0/IWeaver.h>
#include <aidl/android/hardware/weaver/IWeaver.h>

#include <iostream>
#include <unistd.h>
#define ERROR 1
#define LOG(x) std::cout

using namespace android::hardware::weaver;
using android::hardware::hidl_string;
using ::android::hardware::weaver::V1_0::IWeaver;
using ::android::hardware::weaver::V1_0::WeaverConfig;
using ::android::hardware::weaver::V1_0::WeaverReadStatus;
using ::android::hardware::weaver::V1_0::WeaverReadResponse;
using ::android::hardware::weaver::V1_0::WeaverStatus;
using ::android::hardware::Return;
using ::android::sp;

namespace android {
namespace vold {

Weaver::Weaver() {
    const std::string instance = std::string(::aidl::android::hardware::weaver::IWeaver::descriptor) + "/default";
    const bool aidlDeclared = AServiceManager_isDeclared(instance.c_str());
    AIBinder* binder = nullptr;
    if (aidlDeclared) {
        // Do not leave the decrypt UI blocked forever if the vendor Weaver HAL
        // was declared but failed to start.  The songyuan security gate already
        // waits for a stable service; this closes the small race after the gate.
        for (int attempt = 0; attempt < 60 && binder == nullptr; attempt++) {
            binder = AServiceManager_checkService(instance.c_str());
            if (binder == nullptr) usleep(250000);
        }
    }
    if (binder != nullptr) {
        mAidlDevice = ::aidl::android::hardware::weaver::IWeaver::fromBinder(
                ndk::SpAIBinder(binder));
    }
	if (mAidlDevice == nullptr && !aidlDeclared) {
		mDevice = ::android::hardware::weaver::V1_0::IWeaver::getService();
	}
	GottenConfig = false;
}

bool Weaver::GetConfig() {
	if (GottenConfig)
		return true;

	if (mAidlDevice != nullptr) {
		for (int attempt = 0; attempt < 3; attempt++) {
			auto r = mAidlDevice->getConfig(&aidlConfig);
			if (r.isOk() && aidlConfig.keySize > 0 && aidlConfig.valueSize > 0) {
				LOG(ERROR) << "Weaver AIDL getConfig OK on attempt " << (attempt + 1)
					   << " slots=" << aidlConfig.slots
					   << " keySize=" << aidlConfig.keySize
					   << " valueSize=" << aidlConfig.valueSize << "\n";
				GottenConfig = true;
				return true;
			}
			LOG(ERROR) << "Weaver AIDL getConfig failed on attempt " << (attempt + 1)
				   << " status=" << r.getDescription()
				   << " keySize=" << aidlConfig.keySize
				   << " valueSize=" << aidlConfig.valueSize << "\n";
			usleep(250000);
		}
		LOG(ERROR) << "Weaver AIDL backend unavailable; aborting decrypt without further retries\n";
		return false;
	}

	WeaverStatus status;
	WeaverConfig cfg;

	bool callbackCalled = false;
	auto ret = mDevice->getConfig([&](WeaverStatus s, WeaverConfig c) {
		callbackCalled = true;
		status = s;
		cfg = c;
	});
	if (ret.isOk() && callbackCalled && status == WeaverStatus::OK) {
		config = cfg;
		GottenConfig = true;
		return true;
	}
	return false;
}

bool Weaver::GetSlots(uint32_t* slots) {
	if (!GetConfig())
		return false;
	if (mAidlDevice != nullptr) {
		*slots = aidlConfig.slots;
		return true;
	}
	*slots = config.slots;
	return true;
}

bool Weaver::GetKeySize(uint32_t* keySize) {
	if (!GetConfig())
		return false;
	if (mAidlDevice != nullptr) {
		*keySize = aidlConfig.keySize;
		return true;
	}
	*keySize = config.keySize;
	return true;
}

bool Weaver::GetValueSize(uint32_t* valueSize) {
	if (!GetConfig())
		return false;
	if (mAidlDevice != nullptr) {
		*valueSize = aidlConfig.valueSize;
		return true;
	}
	*valueSize = config.valueSize;
	return true;
}

// TODO: we should return more information about the status including time delays before the next retry
bool Weaver::WeaverVerify(const uint32_t slot, const void* weaver_key, std::vector<uint8_t>* payload) {
	bool callbackCalled = false;
	WeaverReadStatus status;
	std::vector<uint8_t> readValue;
	uint32_t timeout;
	uint32_t keySize;
	if (!GetKeySize(&keySize))
		return false;
	std::vector<uint8_t> key;
	key.resize(keySize);
	uint32_t index = 0;
	unsigned char* ptr = (unsigned char*)weaver_key;
	for (index = 0; index < keySize; index++) {
		key[index] = *ptr;
		ptr++;
	}

	if (mAidlDevice != nullptr) {
		::aidl::android::hardware::weaver::WeaverReadResponse rep;
		auto r = mAidlDevice->read(slot, key, &rep);
		if (r.isOk() && rep.status == ::aidl::android::hardware::weaver::WeaverReadStatus::OK) {
			*payload = rep.value;
			return true;
		}
		return false;
	}

	const auto readRet = mDevice->read(slot, key, [&](WeaverReadStatus s, WeaverReadResponse r) {
		callbackCalled = true;
		status = s;
		readValue = r.value;
		timeout = r.timeout;
	});
	if (readRet.isOk() && callbackCalled && status == WeaverReadStatus::OK && timeout == 0) {
		*payload = readValue;
		return true;
	}
	return false;
}

}  // namespace vold
}  // namespace android
