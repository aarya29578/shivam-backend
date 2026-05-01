import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/navigation/app_router.dart';
import 'core/services/offline_image_service.dart';
import 'core/services/upload_queue_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline-first: initialise Hive before anything else
  await Hive.initFlutter();
  await Hive.openBox('captured_images');
  await Hive.openBox('schoolsBox');
  await OfflineImageService.instance.init();
  await UploadQueueService.instance.init();

  await ThemeProvider.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const EduMidApp());
}

class EduMidApp extends StatelessWidget {
  const EduMidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, _) => MaterialApp.router(
        title: 'EDUMID',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeProvider.instance.mode,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
