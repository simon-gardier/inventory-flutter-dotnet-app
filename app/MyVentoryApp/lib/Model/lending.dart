import '../Model/user.dart';
import '../Model/item.dart';

class Lending {
  final int transactionId;
  final int? borrowerId;
  final String borrowerName;
  final String? borrowerEmail;
  final int lenderId;
  final String lenderName;
  final String? lenderEmail;
  final DateTime dueDate;
  final DateTime lendingDate;
  final List<ItemLending>? lendItems;
  final UserAccount? borrower;
  final UserAccount lender;
  final bool? isFinished;

  Lending({
    required this.transactionId,
    this.borrowerId,
    required this.borrowerName,
    this.borrowerEmail,
    required this.lenderId,
    required this.lenderName,
    this.lenderEmail,
    required this.dueDate,
    required this.lendingDate,
    this.lendItems,
    this.borrower,
    required this.lender,
    this.isFinished,
  });

  factory Lending.fromJson(Map<String, dynamic> json) {
    return Lending(
      transactionId: json["transactionId"],
      borrowerId: json["borrowerId"],
      borrowerName: json["borrowerName"],
      borrowerEmail: json["borrowerEmail"],
      lenderId: json["lenderId"],
      lenderName: json["lenderName"],
      lenderEmail: json["lenderEmail"],
      dueDate: DateTime.parse(json["dueDate"]),
      lendingDate: DateTime.parse(json["lendingDate"]),
      lendItems: json["lendItems"] != null
          ? (json["lendItems"] as List<dynamic>)
              .map((item) => ItemLending.fromJson(item))
              .toList()
          : null,
      borrower: json["borrower"] != null
          ? UserAccount.fromJson(json["borrower"])
          : null,
      lender: UserAccount.fromJson(json["lender"]),
      isFinished: json["isFinished"] ?? false,
    );
  }

  Lending copyWith({
    int? transactionId,
    int? borrowerId,
    String? borrowerName,
    String? borrowerEmail,
    int? lenderId,
    String? lenderName,
    String? lenderEmail,
    DateTime? dueDate,
    DateTime? lendingDate,
    List<ItemLending>? lendItems,
    UserAccount? borrower,
    UserAccount? lender,
    bool? isFinished,
  }) {
    return Lending(
      transactionId: transactionId ?? this.transactionId,
      borrowerId: borrowerId ?? this.borrowerId,
      borrowerName: borrowerName ?? this.borrowerName,
      borrowerEmail: borrowerEmail ?? this.borrowerEmail,
      lenderId: lenderId ?? this.lenderId,
      lenderName: lenderName ?? this.lenderName,
      lenderEmail: lenderEmail ?? this.lenderEmail,
      dueDate: dueDate ?? this.dueDate,
      lendingDate: lendingDate ?? this.lendingDate,
      lendItems: lendItems ?? this.lendItems,
      borrower: borrower ?? this.borrower,
      lender: lender ?? this.lender,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

class ItemLending {
  final int transactionId;
  final int itemId;
  final int quantity;
  final Lending lending;
  final InventoryItem item;

  ItemLending({
    required this.transactionId,
    required this.itemId,
    required this.quantity,
    required this.lending,
    required this.item,
  });

  // Factory constructor to create an ItemLending object from JSON
  factory ItemLending.fromJson(Map<String, dynamic> json) {
    return ItemLending(
      transactionId: json["transactionId"],
      itemId: json["itemId"],
      quantity: json["quantity"],
      lending: Lending.fromJson(json["lending"]),
      item: InventoryItem.fromJson(json["item"]),
    );
  }
}
