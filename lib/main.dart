import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart' as home;
import 'screens/inventory_screen.dart';
import 'providers/dashboard_provider.dart';
import 'screens/sales_screen.dart';
import 'screens/calculator.dart';
import 'screens/purchase_screen.dart';
import 'screens/login_screen.dart' as login;
import 'screens/signup_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/report_screen.dart';
import 'screens/peoples_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/simple_notification_screen.dart';

import 'repositories/bill_repository.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/people_repository.dart';
import 'repositories/expense_repository.dart';

import 'cubit/inventory_cubit.dart';
import 'cubit/sales_cubit.dart';
import 'cubit/simple_notification_cubit.dart';
import 'cubit/notification_cubit.dart';

import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'services/simple_notification_service.dart';
import 'services/notification_repository.dart';

import 'themes/app_theme.dart';
import 'utils/refresh_manager.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  //  Enable Firestore offline caching
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  //  Initialize theme
  await ThemeService.initTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillRepository()),
        ChangeNotifierProvider(create: (_) => InventoryRepository()),
        ChangeNotifierProvider(create: (_) => PeopleRepository()),
        ChangeNotifierProvider(create: (_) => ExpenseRepository()),
        ChangeNotifierProvider(create: (_) => RefreshManager()),
        ChangeNotifierProvider(
          create: (context) {
            final dashboardProvider = DashboardProvider(
              billRepo: Provider.of<BillRepository>(context, listen: false),
              inventoryRepo: Provider.of<InventoryRepository>(
                context,
                listen: false,
              ),
              peopleRepo: Provider.of<PeopleRepository>(context, listen: false),
              expenseRepo: Provider.of<ExpenseRepository>(
                context,
                listen: false,
              ),
              userId: FirebaseAuth.instance.currentUser?.uid,
            );
            return dashboardProvider;
          },
        ),
        // Persist ReportProvider at app root for instant, warmed-up reports
        ChangeNotifierProvider<ReportProvider>(
          create: (context) {
            final dashboard =
                Provider.of<DashboardProvider>(context, listen: false);
            return ReportProvider(
              billRepo: Provider.of<BillRepository>(context, listen: false),
              inventoryRepo:
                  Provider.of<InventoryRepository>(context, listen: false),
              peopleRepo:
                  Provider.of<PeopleRepository>(context, listen: false),
              expenseRepo:
                  Provider.of<ExpenseRepository>(context, listen: false),
              refreshManager:
                  Provider.of<RefreshManager>(context, listen: false),
              initialBills: dashboard.bills,
              initialInventory: dashboard.inventory,
              initialPeople: dashboard.people,
              initialExpenses: dashboard.expenses,
            );
          },
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => InventoryCubit(InventoryRepository())),
          BlocProvider(create: (_) => SalesCubit([])),
          BlocProvider(
            create: (_) =>
                SimpleNotificationCubit(service: SimpleNotificationService()),
          ),
          BlocProvider(
            create: (_) => NotificationCubit(
              repository: NotificationRepository(),
              service: NotificationService(),
            ),
          ),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeNotifier,
          builder: (context, mode, _) => MaterialApp(
            title: 'Forward Billing App',
            debugShowCheckedModeBanner: false,
            theme: LightTheme.themeData,
            darkTheme: DarkTheme.themeData,
            // Always follow system setting for dark/light unless app explicitly
            // switches to a specific mode via ThemeService in settings.
            themeMode: mode == ThemeMode.dark || mode == ThemeMode.light
                ? mode
                : ThemeMode.system,
            navigatorObservers: [routeObserver],
            routes: {
              '/login': (context) => const login.LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/forgot_password': (context) => const ForgotPasswordScreen(),
              '/home': (context) => const home.HomeScreen(),
              '/inventory': (context) => const InventoryScreen(),
              '/sales': (context) => const SalesScreen(),
              '/calculator': (context) => const CalculatorScreen(),
              '/purchase': (context) => const PurchaseScreen(),
              '/expense': (context) => const ExpenseScreen(),
              '/reports': (context) => ChangeNotifierProvider<ReportProvider>(
                    create: (context) {
                      final dashboard =
                          Provider.of<DashboardProvider>(context, listen: false);
                      return ReportProvider(
                        billRepo:
                            Provider.of<BillRepository>(context, listen: false),
                        inventoryRepo: Provider.of<InventoryRepository>(context,
                            listen: false),
                        peopleRepo: Provider.of<PeopleRepository>(context,
                            listen: false),
                        expenseRepo: Provider.of<ExpenseRepository>(context,
                            listen: false),
                        refreshManager:
                            Provider.of<RefreshManager>(context, listen: false),
                        initialBills: dashboard.bills,
                        initialInventory: dashboard.inventory,
                        initialPeople: dashboard.people,
                        initialExpenses: dashboard.expenses,
                      );
                    },
                    child: const ReportScreen(),
                  ),
              '/peoples': (context) => const PeoplesScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/notification': (context) => const SimpleNotificationScreen(),
            },
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                // Keep DashboardProvider in sync with the active Firebase user
                final dashboard =
                    Provider.of<DashboardProvider>(context, listen: false);
                if (snapshot.hasData) {
                  final uid = snapshot.data!.uid;
                  if (dashboard.userId != uid) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Schedule after build to avoid setState/markNeedsBuild during build
                      dashboard.setUser(uid);
                    });
                  }
                  return const home.HomeScreen();
                } else {
                  if (dashboard.userId != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      dashboard.setUser(null);
                    });
                  }
                  return const login.LoginScreen();
                }
              },
            ),
          ),
        ),
      ),
    ),
  );
}
