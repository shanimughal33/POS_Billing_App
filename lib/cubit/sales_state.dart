part of 'sales_cubit.dart';

abstract class SalesState {}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesUpdated extends SalesState {
  final List<BillItem> items;
  SalesUpdated(this.items);
}

class SalesEditing extends SalesState {
  final BillItem item;
  SalesEditing(this.item);
}

class SalesError extends SalesState {
  final String message;
  SalesError(this.message);
}
