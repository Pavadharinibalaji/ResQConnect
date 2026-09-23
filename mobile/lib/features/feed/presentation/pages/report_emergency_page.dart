import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/services/location_service.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';

class ReportEmergencyPage extends ConsumerStatefulWidget {
  const ReportEmergencyPage({super.key});

  @override
  ConsumerState<ReportEmergencyPage> createState() => _ReportEmergencyPageState();
}

class _ReportEmergencyPageState extends ConsumerState<ReportEmergencyPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();

  String _selectedCategory = 'medical';
  String _selectedSeverity = 'high';
  bool _isLoading = false;

  final _categories = ['fire', 'medical', 'flood', 'crime', 'rescue'];
  final _severities = ['low', 'medium', 'high', 'critical'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final position = await _locationService.getCurrentLocation();
      final lat = position?.latitude ?? 12.9716;
      final lng = position?.longitude ?? 77.5946;

      ref.read(incidentProvider.notifier).updateDraft(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _selectedCategory,
            severity: _selectedSeverity,
            latitude: lat,
            longitude: lng,
          );

      final created = await ref.read(incidentProvider.notifier).createIncident();

      if (mounted) {
        if (created != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Emergency reported successfully!')),
          );
          context.go('/incident/${created.id}');
        } else {
          final error = ref.read(incidentProvider).errorMessage ?? 'Error reporting emergency.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reporting emergency: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Emergency'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Incident Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSeverity,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        border: OutlineInputBorder(),
                      ),
                      items: _severities
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSeverity = val);
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text(
                        'SUBMIT EMERGENCY NOW',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
