package com.example.money_tracker

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt used by
// the app lock is an AndroidX fragment and needs a FragmentActivity host.
// Under a plain FlutterActivity it throws as soon as the user enables the lock.
class MainActivity : FlutterFragmentActivity()
