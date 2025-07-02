import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forward_billing_app/screens/home_screen.dart';
import 'package:forward_billing_app/screens/inventory_screen.dart';
import 'package:forward_billing_app/screens/Calculator.dart';
import 'cubit/inventory_cubit.dart';
import 'cubit/sales_cubit.dart';
import 'repositories/inventory_repository.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InventoryCubit>(
          create: (_) => InventoryCubit(InventoryRepository())..loadInventory(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Customer Bill App',
        theme: ThemeData(
          primaryColor: const Color(0xFF128C7E),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF128C7E),
            primary: const Color(0xFF128C7E),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF128C7E),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == '/sales') {
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  BlocProvider<SalesCubit>(
                    create: (_) =>
                        SalesCubit(context.read<InventoryCubit>().items),
                    child: const CalculatorScreen(),
                  ),
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOutCubic;
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
            );
          } else {
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const InventoryScreen(),
              transitionDuration: const Duration(milliseconds: 100),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOutCubic;
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
            );
          }
        },
        home: const HomeScreen(),
      ),
    );
  }
}
