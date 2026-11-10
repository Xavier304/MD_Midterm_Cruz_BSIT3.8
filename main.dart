import 'dart:io';

enum RecordStatus { active, inactive, pending }

class InputEndedException implements Exception {
  @override
  String toString() => 'No more input available.';
}

mixin Timestamped {
  DateTime? _createdAt;
  void stampCreation() => _createdAt = DateTime.now();
  String get createdAtLabel => _createdAt?.toString().substring(0, 19) ?? 'N/A';
}

mixin StatusTrackable {
  RecordStatus status = RecordStatus.pending;
  String get statusLabel =>
      status.name[0].toUpperCase() + status.name.substring(1);
}

abstract class CenterRecord {
  final String id;
  String name;

  CenterRecord(String id, String name)
      : id = id.trim(),
        name = name.trim() {
    if (this.id.isEmpty) throw ArgumentError('ID cannot be empty.');
    if (this.name.isEmpty) throw ArgumentError('Name cannot be empty.');
  }

  void displayDetails();
}

class Participant extends CenterRecord with Timestamped, StatusTrackable {
  final String contactInfo;
  double totalPaid = 0;
  final List<String> enrolled = [];

  Participant(super.id, super.name, String contact, RecordStatus initial)
      : contactInfo = contact.trim() {
    if (contactInfo.length < 5) {
      throw ArgumentError('Contact info must be at least 5 characters.');
    }
    status = initial;
    stampCreation();
  }

  bool get isActive => status == RecordStatus.active;

  @override
  void displayDetails() {
    print('[Participant] $id - $name');
    print('   Contact : $contactInfo');
    print('   Status  : $statusLabel');
    print('   Created : $createdAtLabel');
    print('   Paid    : PHP ${totalPaid.toStringAsFixed(2)}');
    print('   Enrolled: ${enrolled.isEmpty ? "none" : enrolled.join(", ")}');
  }
}

class LearningResource extends CenterRecord with Timestamped, StatusTrackable {
  final double fee;
  final String type;
  int quantity;

  LearningResource(super.id, super.name, this.fee, this.type, this.quantity) {
    if (fee < 0) throw ArgumentError('Fee cannot be negative.');
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative.');
    status = quantity > 0 ? RecordStatus.active : RecordStatus.inactive;
    stampCreation();
  }

  void reduceStock(int amount) {
    quantity -= amount;
    if (quantity == 0) status = RecordStatus.inactive;
  }

  @override
  void displayDetails() {
    print('[Resource] $id - $name');
    print('   Type    : $type');
    print('   Fee     : PHP ${fee.toStringAsFixed(2)}');
    print('   Slots   : $quantity');
    print('   Status  : $statusLabel');
    print('   Created : $createdAtLabel');
  }
}

final Map<String, CenterRecord> records = {};
bool running = true;

String key(String id) => id.trim().toUpperCase();

T? find<T>(String id) {
  final record = records[key(id)];
  return record is T ? record as T : null;
}

String ask(String prompt) {
  stdout.write(prompt);
  final value = stdin.readLineSync();
  if (value == null) {
    print('');
    throw InputEndedException();
  }
  return value;
}

String readRequired(String prompt) {
  while (true) {
    final value = ask(prompt).trim();
    if (value.isNotEmpty) return value;
    print('  ! Input cannot be empty. Please try again.');
  }
}

int readInt(String prompt, {int min = 0, int max = 1000000}) {
  while (true) {
    final value = int.tryParse(ask(prompt).trim());
    if (value == null) {
      print('  ! Invalid number. Please enter a whole number.');
    } else if (value < min || value > max) {
      print('  ! Enter a whole number from $min to $max.');
    } else {
      return value;
    }
  }
}

double readDouble(String prompt, {double min = 0}) {
  while (true) {
    final value = double.tryParse(ask(prompt).trim());
    if (value == null) {
      print('  ! Invalid amount. Please enter a number (e.g., 500 or 99.50).');
    } else if (value < min) {
      print('  ! Value must be at least $min.');
    } else {
      return value;
    }
  }
}

T choose<T>(String prompt, List<T> options) =>
    options[readInt(prompt, min: 1, max: options.length) - 1];

void registerParticipant() {
  print('\n--- Register New Participant ---');
  final name = readRequired('Full name: ');
  final id = readRequired('Participant ID: ');
  if (records.containsKey(key(id))) {
    print('  ! ID "$id" already exists. Registration cancelled.');
    return;
  }
  final contact = readRequired('Contact info (phone/email): ');
  final status = choose('Status (1=Active, 2=Inactive, 3=Pending): ',
      [RecordStatus.active, RecordStatus.inactive, RecordStatus.pending]);
  try {
    final participant = Participant(id, name, contact, status);
    records[key(participant.id)] = participant;
    print('  Participant "$name" registered successfully.');
  } on ArgumentError catch (e) {
    print('  ! Could not register participant: ${e.message}');
  }
}

void addLearningResource() {
  print('\n--- Add New Learning Resource ---');
  final id = readRequired('Resource ID: ');
  if (records.containsKey(key(id))) {
    print('  ! ID "$id" already exists. Operation cancelled.');
    return;
  }
  final title = readRequired('Title: ');
  final fee = readDouble('Fee (PHP): ');
  final type = choose('Type (1=Workshop, 2=Book, 3=Online Course): ',
      ['Workshop', 'Book', 'Online Course']);
  final quantity = readInt('Available slots/copies: ', min: 1);
  try {
    final resource = LearningResource(id, title, fee, type, quantity);
    records[key(resource.id)] = resource;
    print('  Resource "$title" added successfully.');
  } on ArgumentError catch (e) {
    print('  ! Could not add resource: ${e.message}');
  }
}

void processTransaction() {
  print('\n--- Process Transaction / Calculate Fees ---');
  final participant = find<Participant>(readRequired('Participant ID: '));
  if (participant == null) {
    print('  ! Participant not found.');
    return;
  }
  if (!participant.isActive) {
    print('  ! ${participant.name} is ${participant.statusLabel}. Only Active participants can transact.');
    return;
  }
  final resource = find<LearningResource>(readRequired('Resource ID: '));
  if (resource == null) {
    print('  ! Resource not found.');
    return;
  }
  if (resource.quantity == 0) {
    print('  ! "${resource.name}" has no slots/copies left.');
    return;
  }

  final quantity = readInt('Quantity (1-${resource.quantity}): ',
      min: 1, max: resource.quantity);
  final subtotal = resource.fee * quantity;
  final rate = 0.10 + (subtotal >= 1000 ? 0.05 : 0.0);
  final total = subtotal - subtotal * rate;

  print('  Subtotal : PHP ${subtotal.toStringAsFixed(2)}');
  print('  Discount : ${(rate * 100).toStringAsFixed(0)}%');
  print('  Total due: PHP ${total.toStringAsFixed(2)}');

  final paid = readDouble('Amount paid (PHP): ');
  if (paid < total) {
    print('  ! Insufficient payment. Short by PHP ${(total - paid).toStringAsFixed(2)}. Transaction cancelled.');
    return;
  }

  resource.reduceStock(quantity);
  participant.totalPaid += total;
  if (!participant.enrolled.contains(resource.id)) {
    participant.enrolled.add(resource.id);
  }
  print('  Transaction complete. Change: PHP ${(paid - total).toStringAsFixed(2)}');
}

void viewAndSearchRecords() {
  print('\n--- View / Search Records ---');
  final choice = readInt('1=View all records, 2=Search by ID: ', min: 1, max: 2);

  if (choice == 1) {
    if (records.isEmpty) {
      print('  No records yet.');
      return;
    }
    print('');
    for (final record in records.values) {
      record.displayDetails();
      print('');
    }
    print('  Total records: ${records.length}');
  } else {
    final record = records[key(readRequired('Enter ID to search: '))];
    if (record == null) {
      print('  ! No record found with that ID.');
    } else {
      print('');
      record.displayDetails();
    }
  }
}

void exitApp() {
  print('\nThank you for using the system. Goodbye!');
  running = false;
}

void main() {
  final menu = <String, void Function()>{
    'Register a new Participant': registerParticipant,
    'Add a new Learning Resource': addLearningResource,
    'Process Transaction / Calculate Fees': processTransaction,
    'View All Records & Search by ID': viewAndSearchRecords,
    'Exit': exitApp,
  };
  final actions = menu.values.toList();

  while (running) {
    try {
      print('\n==============================================');
      print('  COMMUNITY LEARNING CENTER MANAGEMENT SYSTEM');
      print('==============================================');
      var n = 1;
      for (final label in menu.keys) {
        print('  ${n++}. $label');
      }
      print('----------------------------------------------');

      final choice = int.tryParse(ask('Choose an option (1-5): ').trim());
      if (choice == null) {
        print('  ! Invalid input. Please enter a number from 1 to 5.');
      } else if (choice < 1 || choice > actions.length) {
        print('  ! Invalid option. Please choose 1-5.');
      } else {
        actions[choice - 1]();
      }
    } on InputEndedException {
      print('\nInput ended. Exiting program.');
      running = false;
    } catch (e) {
      print('  ! Unexpected error: $e');
    }
  }
}