import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

void main() {
  runApp(const TranslationEditorApp());
}

class TranslationEditorApp extends StatelessWidget {
  const TranslationEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Translation Locale Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TranslationEditorHome(),
    );
  }
}

class TranslationEditorHome extends StatefulWidget {
  const TranslationEditorHome({super.key});

  @override
  State<TranslationEditorHome> createState() => _TranslationEditorHomeState();
}

class _TranslationEditorHomeState extends State<TranslationEditorHome> {
  Map<String, dynamic> _translations = {};
  List<String> _availableLocales = [];
  String? _selectedLocale;
  String _searchQuery = '';
  bool _hasUnsavedChanges = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadTranslationFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        Map<String, dynamic> newTranslations = {};
        List<String> newLocales = [];

        for (PlatformFile file in result.files) {
          try {
            String content;

            if (file.bytes != null) {
              content = String.fromCharCodes(file.bytes!);
            } else if (file.path != null) {
              final fileObj = File(file.path!);
              content = await fileObj.readAsString();
            } else {
              continue;
            }

            final data = json.decode(content) as Map<String, dynamic>;

            final locale = path.basenameWithoutExtension(file.name);
            newTranslations[locale] = data;
            newLocales.add(locale);
          } catch (e) {
            _showErrorDialog('Error parsing ${file.name}: $e');
          }
        }

        if (newTranslations.isNotEmpty) {
          setState(() {
            _translations = newTranslations;
            _availableLocales = newLocales;
            _selectedLocale = newLocales.first;
            _hasUnsavedChanges = false;
          });
        } else {
          _showErrorDialog('No valid JSON files were loaded');
        }
      }
    } catch (e) {
      _showErrorDialog('Error loading files: $e');
    }
  }

  void _updateTranslation(String key, String value) {
    if (_selectedLocale != null && _translations.containsKey(_selectedLocale)) {
      setState(() {
        _translations[_selectedLocale!][key] = value;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _closeLocale(String locale) {
    if (_hasUnsavedChanges) {
      _showCloseConfirmationDialog(locale);
    } else {
      _performCloseLocale(locale);
    }
  }

  void _showCloseConfirmationDialog(String locale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text(
          'You have unsaved changes in $locale. Do you want to save before closing?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performCloseLocale(locale);
            },
            child: const Text('Close Without Saving'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _exportTranslations();
              _performCloseLocale(locale);
            },
            child: const Text('Save & Close'),
          ),
        ],
      ),
    );
  }

  void _performCloseLocale(String locale) {
    setState(() {
      _translations.remove(locale);
      _availableLocales.remove(locale);

      if (_selectedLocale == locale) {
        _selectedLocale = _availableLocales.isNotEmpty
            ? _availableLocales.first
            : null;
        _searchQuery = '';
        _searchController.clear();
      }

      if (_availableLocales.isEmpty) {
        _hasUnsavedChanges = false;
      }
    });
  }

  Future<void> _exportTranslations() async {
    if (_selectedLocale == null ||
        !_translations.containsKey(_selectedLocale)) {
      _showErrorDialog('No translations to export');
      return;
    }

    try {
      String? outputDir = await FilePicker.platform.getDirectoryPath();
      if (outputDir != null) {
        final localeData = _translations[_selectedLocale!];

        final sortedData = Map.fromEntries(
          localeData.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        );

        final jsonString = const JsonEncoder.withIndent(
          '  ',
        ).convert(sortedData);
        final outputFile = File(
          path.join(outputDir, '${_selectedLocale}.json'),
        );
        await outputFile.writeAsString(jsonString);

        _showSuccessDialog('Translations exported to ${outputFile.path}');
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error exporting translations: $e');
    }
  }

  Future<void> _exportAllTranslations() async {
    try {
      String? outputDir = await FilePicker.platform.getDirectoryPath();
      if (outputDir != null) {
        for (String locale in _availableLocales) {
          if (_translations.containsKey(locale)) {
            final localeData = _translations[locale];

            final sortedData = Map.fromEntries(
              localeData.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key)),
            );

            final jsonString = const JsonEncoder.withIndent(
              '  ',
            ).convert(sortedData);
            final outputFile = File(path.join(outputDir, '$locale.json'));
            await outputFile.writeAsString(jsonString);
          }
        }

        _showSuccessDialog('All translations exported to $outputDir');
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error exporting translations: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<String> _getFilteredKeys() {
    if (_selectedLocale == null ||
        !_translations.containsKey(_selectedLocale)) {
      return [];
    }

    final localeData = _translations[_selectedLocale!] as Map<String, dynamic>;
    final keys = localeData.keys.toList()..sort();

    if (_searchQuery.isEmpty) {
      return keys;
    }

    return keys
        .where(
          (key) =>
              key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (localeData[key] as String? ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Locale Editor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_hasUnsavedChanges)
            const Icon(Icons.circle, color: Colors.orange, size: 12),
          const SizedBox(width: 8),
        ],
      ),
      body: _translations.isEmpty
          ? _buildEmptyState()
          : _buildEditorInterface(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.translate, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'No Translation Files Loaded',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Load JSON translation files to start editing',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _loadTranslationFiles,
            icon: const Icon(Icons.folder_open),
            label: const Text('Load Translation Files'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorInterface() {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            children: [
              _buildLocaleSelector(),
              Expanded(child: _buildTranslationList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _loadTranslationFiles,
            icon: const Icon(Icons.folder_open),
            label: const Text('Load Files'),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _exportTranslations,
            icon: const Icon(Icons.download),
            label: const Text('Export Current'),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _exportAllTranslations,
            icon: const Icon(Icons.download),
            label: const Text('Export All'),
          ),
          const Spacer(),
          if (_hasUnsavedChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Unsaved Changes',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocaleSelector() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Locales',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _availableLocales.length,
              itemBuilder: (context, index) {
                final locale = _availableLocales[index];
                final isSelected = locale == _selectedLocale;
                final keyCount = _translations[locale]?.keys.length ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    title: Text(
                      locale.toUpperCase(),
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('$keyCount translation keys'),
                    onTap: () {
                      setState(() {
                        _selectedLocale = locale;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _closeLocale(locale),
                          tooltip: 'Close $locale',
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.red[600],
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(24, 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationList() {
    if (_selectedLocale == null ||
        !_translations.containsKey(_selectedLocale)) {
      return const Center(child: Text('Select a locale to view translations'));
    }

    final filteredKeys = _getFilteredKeys();

    return Column(
      children: [
        _buildSearchBar(),
        _buildTranslationHeader(filteredKeys.length),
        Expanded(
          child: ListView.builder(
            itemCount: filteredKeys.length,
            itemBuilder: (context, index) {
              final key = filteredKeys[index];
              final value =
                  _translations[_selectedLocale!][key] as String? ?? '';

              return _buildTranslationItem(key, value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationHeader(int totalKeys) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.translate,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Translation Keys',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalKeys keys',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search translations...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildTranslationItem(String key, String value) {
    final TextEditingController valueController = TextEditingController(
      text: value,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.key,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Translation Key:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              key,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.translate,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Translation Value:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valueController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Enter translation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (newValue) {
                _updateTranslation(key, newValue);
              },
            ),
          ],
        ),
      ),
    );
  }
}
