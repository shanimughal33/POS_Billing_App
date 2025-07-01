part of 'sales_cubit.dart';

abstract class SalesState {}

class SalesInitial extends SalesState {}

class SalesUpdated extends SalesState {
  final List<BillItem> items;
  SalesUpdated(this.items);
}

class SalesError extends SalesState {
  final String message;
  SalesError(this.message);
}
