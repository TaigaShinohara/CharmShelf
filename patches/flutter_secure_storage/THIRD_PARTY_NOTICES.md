# Third-party notices

The Flutter Secure Storage implementation and cipher wire formats are based on
flutter_secure_storage 11.2.0 and 10.3.4, Copyright 2017 German Saprykin and
contributors, under the BSD 3-Clause license in `LICENSE`.

The legacy EncryptedSharedPreferences wire-format compatibility code is adapted
from the AndroidX implementation retained in flutter_secure_storage 10.3.4:

Copyright 2019 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Changes: read-only string decoding only; legacy key creation and mutation are
disabled; original ciphertext is protected by a durable migration journal.
