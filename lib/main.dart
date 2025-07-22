import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forward_billing_app/screens/home_screen.dart';
import 'package:forward_billing_app/screens/inventory_screen.dart';
import 'package:forward_billing_app/screens/sales_screen.dart';
import 'package:forward_billing_app/screens/calculator.dart';
import 'package:forward_billing_app/screens/purchase_screen.dart';
import 'package:forward_billing_app/screens/login_screen.dart';
import 'package:forward_billing_app/screens/signup_screen.dart';
import 'package:forward_billing_app/screens/expense_screen.dart';
import 'package:forward_billing_app/screens/report_screen.dart';
import 'package:forward_billing_app/screens/peoples_screen.dart';
import 'package:forward_billing_app/screens/settings_screen.dart';
import 'package:forward_billing_app/screens/forgot_password_screen.dart';
import 'cubit/inventory_cubit.dart';
import 'cubit/sales_cubit.dart';
import 'repositories/inventory_repository.dart';
import 'database/database_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => InventoryCubit(InventoryRepository()),
        ),
        BlocProvider(
          create: (context) {
            final inventoryCubit = context.read<InventoryCubit>();
            return SalesCubit(inventoryCubit.items);
          },
        ),
      ],
      child: MaterialApp(
        title: 'Forward Billing App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
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
