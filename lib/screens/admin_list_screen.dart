import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

enum AdminListKind { bookings, payments, users }

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key, required this.kind});

  final AdminListKind kind;

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<String> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _title {
    switch (widget.kind) {
      case AdminListKind.bookings:
        return 'Manage bookings';
      case AdminListKind.payments:
        return 'Payments';
      case AdminListKind.users:
        return 'Manage users';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lines = <String>[];
      switch (widget.kind) {
        case AdminListKind.bookings:
          final b = await _api.fetchAllBookings();
          for (final x in b) {
            final idShort = x.id.length >= 8 ? '${x.id.substring(0, 8)}…' : x.id;
            lines.add('$idShort · ${x.status} · ${x.sessionType}');
          }
          break;
        case AdminListKind.payments:
          final p = await _api.fetchAllPayments();
          for (final x in p) {
            final idShort = x.id.length >= 8 ? '${x.id.substring(0, 8)}…' : x.id;
            lines.add('$idShort · ${x.status} · ${x.amount ?? "—"}');
          }
          break;
        case AdminListKind.users:
          final u = await _api.fetchAllUsersForAdmin();
          for (final x in u) {
            lines.add('${x.fullName} · ${x.email} · ${x.role}${x.isAvailable ? " · available" : ""}');
          }
          break;
      }
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: SmartAfyaPalette.primaryBlue,
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue))
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _load,
                                style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _lines.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('No records.')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _lines.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              title: Text(_lines[i], style: const TextStyle(fontSize: 14)),
                            ),
                          ),
                        ),
        ),
      ),
    );
  }
}
