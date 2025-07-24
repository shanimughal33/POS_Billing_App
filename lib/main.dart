import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/calculator.dart';
import 'screens/purchase_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/report_screen.dart';
import 'screens/peoples_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'repositories/bill_repository.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/people_repository.dart';
import 'repositories/expense_repository.dart';
import 'database/database_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubit/inventory_cubit.dart';
import 'cubit/sales_cubit.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize sqflite_common_ffi for desktop platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await DatabaseHelper.instance.database;
    debugPrint('Database initialized successfully');
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    
    // Try to reset the database if there's a migration issue
    try {
      await DatabaseHelper.instance.resetDatabase();
      await DatabaseHelper.instance.database;
      debugPrint('Database reset and reinitialized successfully');
    } catch (resetError) {
      debugPrint('Database reset failed: $resetError');
      // Continue with app launch even if database fails
    }
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillRepository()),
        ChangeNotifierProvider(create: (_) => InventoryRepository()),
        ChangeNotifierProvider(create: (_) => PeopleRepository()),
        ChangeNotifierProvider(create: (_) => ExpenseRepository()),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            billRepo: Provider.of<BillRepository>(context, listen: false),
            inventoryRepo: Provider.of<InventoryRepository>(context, listen: false),
            peopleRepo: Provider.of<PeopleRepository>(context, listen: false),
            expenseRepo: Provider.of<ExpenseRepository>(context, listen: false),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => InventoryCubit(InventoryRepository())),
          BlocProvider(
            create: (context) => SalesCubit([]),
          ),
          // Add other cubits here if needed
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, child) => MaterialApp(
            title: 'Forward Billing App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF1976D2),
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: const Color(0xFF101624),
              cardColor: const Color(0xFF1A2233),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF101624),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              colorScheme: ColorScheme.dark(
                primary: Color(0xFF1976D2),
                secondary: Color(0xFF42A5F5),
              ),
            ),
            themeMode: mode,
            navigatorObservers: [routeObserver],
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/forgot_password': (context) => const ForgotPasswordScreen(),
              '/home': (context) => const HomeScreen(),
              '/inventory': (context) => const InventoryScreen(),
              '/sales': (context) => const SalesScreen(),
              '/calculator': (context) => const CalculatorScreen(),
              '/purchase': (context) => const PurchaseScreen(),
              '/expense': (context) => const ExpenseScreen(),
              '/reports': (context) => const ReportScreen(),
              '/peoples': (context) => const PeoplesScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
            home: FutureBuilder(
              future: Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasData) {
                      return const HomeScreen();
                    } else {
                      return const LoginScreen();
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillRepository()),
        ChangeNotifierProvider(create: (_) => InventoryRepository()),
        ChangeNotifierProvider(create: (_) => PeopleRepository()),
        ChangeNotifierProvider(create: (_) => ExpenseRepository()),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            billRepo: Provider.of<BillRepository>(context, listen: false),
            inventoryRepo: Provider.of<InventoryRepository>(context, listen: false),
            peopleRepo: Provider.of<PeopleRepository>(context, listen: false),
            expenseRepo: Provider.of<ExpenseRepository>(context, listen: false),
          ),
        ),
      ],
      child: MaterialApp(
      title: 'Forward Billing App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
        navigatorObservers: [routeObserver],
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
          '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
          '/inventory': (context) => const InventoryScreen(),
          '/sales': (context) => const SalesScreen(),
          '/calculator': (context) => const CalculatorScreen(),
          '/purchase': (context) => const PurchaseScreen(),
          '/expense': (context) => const ExpenseScreen(),
          '/reports': (context) => const ReportScreen(),
          '/peoples': (context) => const PeoplesScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
        home: FutureBuilder(
          future: Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
            );
          },
        ),
      ),
    );
  }
}
