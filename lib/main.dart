import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uqyhiyzvfhhxjxwtjwxq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxeWhpeXp2ZmhoeGp4d3Rqd3hxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkxOTA5MDksImV4cCI6MjA3NDc2NjkwOX0.-w0-pZmugiKkvlZ5VRJl6ZvUn7Xaq_G8ayU6_jYbjHQ',
  );

  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}