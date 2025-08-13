import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

// -- Global ScaffoldMessenger (snackbars persist across navigation)
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyC8OMB40hChWr4ngld1Gv6eqFIwLifcThI",
      authDomain: "expensetracker-8f28a.firebaseapp.com",
      projectId: "expensetracker-8f28a",
      storageBucket: "expensetracker-8f28a.firebasestorage.app",
      messagingSenderId: "400648425641",
      appId: "1:400648425641:web:7e980e025e722db2ae99b8",
      measurementId: "G-59M8LKCS89",
    ),
  );
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      home: const ListPage(),
    );
  }
}

// -------------------- LISTS PAGE --------------------
class ListPage extends StatelessWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final listsRef = FirebaseFirestore.instance.collection('lists');

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Lists')),
      body: StreamBuilder<QuerySnapshot>(
        stream: listsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final lists = snapshot.data!.docs;

          if (lists.isEmpty) {
            return const Center(
              child: Text(
                "No lists yet. Tap + to create one.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, i) {
              final list = lists[i];
              final listName = (list.data() as Map)['name'] ?? '';

              return Card(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.list_alt, color: Colors.green),
                  title: Text(listName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListDetailPage(listId: list.id, listName: listName),
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Rename',
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _renameListDialog(context, list.id, listName),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteList(context, list.id, listName),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("New List"),
        onPressed: () => _addListDialog(context),
      ),
    );
  }

  Future<void> _addListDialog(BuildContext context) async {
    final controller = TextEditingController();
    final listsRef = FirebaseFirestore.instance.collection('lists');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'List Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await listsRef.doc().set({'name': name});
              }
              if (context.mounted) Navigator.pop(context);
              rootScaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('List added')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameListDialog(BuildContext context, String listId, String currName) async {
    final controller = TextEditingController(text: currName);
    final listsRef = FirebaseFirestore.instance.collection('lists');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'List Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await listsRef.doc(listId).update({'name': name});
              }
              if (context.mounted) Navigator.pop(context);
              rootScaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('List renamed')),
              );
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteList(BuildContext context, String listId, String listName) async {
    final listsRef = FirebaseFirestore.instance.collection('lists');

    // capture data (list + entries) BEFORE deletion for Undo (including IDs)
    final listSnap = await listsRef.doc(listId).get();
    final Map<String, dynamic> listData = Map<String, dynamic>.from(listSnap.data() ?? {});
    final entriesSnap = await listsRef.doc(listId).collection('entries').get();
    final entriesData = entriesSnap.docs
        .map<Map<String, dynamic>>((d) => {
              'id': d.id,
              'data': Map<String, dynamic>.from(d.data() as Map),
            })
        .toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Delete list "$listName" and all its entries?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.5),
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // delete list + its entries in a batch
    final batch = FirebaseFirestore.instance.batch();
    for (final e in entriesSnap.docs) {
      batch.delete(e.reference);
    }
    batch.delete(listsRef.doc(listId));
    await batch.commit();

    // Global snackbar (persists even if you navigate)
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        content: Text('List "$listName" deleted', style: const TextStyle(color: Colors.green)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.green,
          onPressed: () async {
            final listRef = listsRef.doc(listId);
            await listRef.set(listData);
            for (final e in entriesData) {
              await listRef
                  .collection('entries')
                  .doc(e['id'] as String)
                  .set(Map<String, dynamic>.from(e['data'] as Map));
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// -------------------- LIST DETAIL PAGE --------------------
class ListDetailPage extends StatefulWidget {
  final String listId;
  final String listName;
  const ListDetailPage({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  @override
  Widget build(BuildContext context) {
    final entriesQuery = FirebaseFirestore.instance
        .collection('lists')
        .doc(widget.listId)
        .collection('entries')
        .orderBy('dateTime', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _showReportDialog(context),
            tooltip: "Show Report",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: entriesQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snapshot.data!.docs;

          if (entries.isEmpty) {
            return const Center(
              child: Text("No entries yet. Tap + to add one.",
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              final Timestamp ts = e['dateTime'] as Timestamp;
              final dt = ts.toDate();
              final qty = (e['quantity'] as num?)?.toInt() ?? 1;
              final price = (e['price'] as num?)?.toDouble() ?? 0.0;
              final total = price * qty;

              return Card(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.attach_money, color: Colors.green),
                  title: Text("${e['item']} (x$qty)",
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    "₹${price.toStringAsFixed(2)} • ${DateFormat('yyyy-MM-dd HH:mm').format(dt)}"
                    "\nTotal: ₹${total.toStringAsFixed(2)}",
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEntryDialog(context, entry: e, entryId: e.id),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Entry'),
                              content: Text('Are you sure you want to delete "${e['item']}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red, width: 1.5),
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final entriesRef = FirebaseFirestore.instance
                                .collection('lists')
                                .doc(widget.listId)
                                .collection('entries');

                            // save original data for Undo (keep same id)
                            final deletedData = Map<String, dynamic>.from(e.data() as Map);

                            await entriesRef.doc(e.id).delete();

                            rootScaffoldMessengerKey.currentState?.showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.white,
                                content: Text(
                                  'Entry "${e['item']}" deleted',
                                  style: const TextStyle(color: Colors.green),
                                ),
                                duration: const Duration(seconds: 4),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  textColor: Colors.green,
                                  onPressed: () async {
                                    await entriesRef.doc(e.id).set(deletedData);
                                  },
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Entry"),
        onPressed: () => _showEntryDialog(context),
      ),
    );
  }

  Future<void> _showEntryDialog(
    BuildContext context, {
    DocumentSnapshot? entry,
    String? entryId,
  }) async {
    final itemCtrl = TextEditingController(text: entry?['item'] ?? '');
    final priceCtrl = TextEditingController(text: (entry?['price']?.toString() ?? ''));
    final qtyCtrl = TextEditingController(text: (entry?['quantity']?.toString() ?? '1'));

    DateTime dateTime = entry?['dateTime'] != null
        ? (entry!['dateTime'] as Timestamp).toDate()
        : DateTime.now();

    final entriesRef = FirebaseFirestore.instance
        .collection('lists')
        .doc(widget.listId)
        .collection('entries');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry == null ? 'Add Entry' : 'Edit Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item')),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(dateTime)}'),
                ),
                IconButton(
                  tooltip: 'Pick date & time',
                  icon: const Icon(Icons.calendar_today, color: Colors.green),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateTime,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(dateTime),
                      );
                      if (time != null) {
                        setState(() {
                          dateTime = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final item = itemCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              if (item.isEmpty || price <= 0) return;

              final data = {
                'item': item,
                'price': price,
                'quantity': qty,
                'dateTime': Timestamp.fromDate(dateTime),
              };

              if (entry == null) {
                await entriesRef.add(data);
              } else {
                await entriesRef.doc(entryId).update(data);
              }
              if (context.mounted) Navigator.pop(context);

              rootScaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(entry == null ? 'Entry added' : 'Entry updated'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final entriesRef = FirebaseFirestore.instance
        .collection('lists')
        .doc(widget.listId)
        .collection('entries');

    final entriesSnap = await entriesRef.get();
    final entries = entriesSnap.docs;

    double totalExpense = 0;
    double weeklyExpense = 0;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    for (final e in entries) {
      final d = (e['dateTime'] as Timestamp).toDate();
      final amt = (e['price'] as num) * (e['quantity'] as num);
      totalExpense += amt;
      if (d.isAfter(weekAgo)) weeklyExpense += amt;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total Expense: ₹${totalExpense.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('Last 7 days: ₹${weeklyExpense.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}