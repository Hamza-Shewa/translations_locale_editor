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
          // Synchronize keys across all translation files
          _synchronizeTranslationKeys(newTranslations);

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

  void _synchronizeTranslationKeys(Map<String, dynamic> translations) {
    // Collect all unique keys from all translation files
    Set<String> allKeys = {};
    for (String locale in translations.keys) {
      final localeData = translations[locale] as Map<String, dynamic>;
      allKeys.addAll(localeData.keys);
    }

    // Add missing keys to each translation file with empty values
    for (String locale in translations.keys) {
      final localeData = translations[locale] as Map<String, dynamic>;
      for (String key in allKeys) {
        if (!localeData.containsKey(key)) {
          localeData[key] = ''; // Add empty value for missing keys
        }
      }
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

  void _addNewKey(String newKey) {
    if (newKey.isNotEmpty && _selectedLocale != null) {
      // Add the new key to all translation files
      for (String locale in _translations.keys) {
        final localeData = _translations[locale] as Map<String, dynamic>;
        if (!localeData.containsKey(newKey)) {
          localeData[newKey] = ''; // Add empty value for new key
        }
      }

      setState(() {
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

  void _showAddKeyDialog() {
    final TextEditingController keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Translation Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Key Name',
                hintText: 'Enter the translation key (e.g., welcome_message)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'This key will be added to all loaded translation files with empty values.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newKey = keyController.text.trim();
              if (newKey.isNotEmpty) {
                _addNewKey(newKey);
                Navigator.of(context).pop();
                _showSuccessDialog(
                  'Key "$newKey" added to all translation files',
                );
              }
            },
            child: const Text('Add Key'),
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
    List<String> keys = localeData.keys.toList();

    // Filter by search query if provided
    if (_searchQuery.isNotEmpty) {
      keys = keys
          .where(
            (key) =>
                key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (localeData[key] as String? ?? '').toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    // Sort: empty values first, then filled values alphabetically
    keys.sort((a, b) {
      final valueA = localeData[a] as String? ?? '';
      final valueB = localeData[b] as String? ?? '';

      final isEmptyA = valueA.isEmpty;
      final isEmptyB = valueB.isEmpty;

      // If one is empty and the other isn't, empty comes first
      if (isEmptyA && !isEmptyB) return -1;
      if (!isEmptyA && isEmptyB) return 1;

      // If both are empty or both are filled, sort alphabetically
      return a.compareTo(b);
    });

    return keys;
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
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _showAddKeyDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Key'),
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
        _buildTranslationHeader(filteredKeys),
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

  Widget _buildTranslationHeader(List<String> filteredKeys) {
    if (_selectedLocale == null ||
        !_translations.containsKey(_selectedLocale)) {
      return const SizedBox.shrink();
    }

    final localeData = _translations[_selectedLocale!] as Map<String, dynamic>;
    final totalKeys = filteredKeys.length;
    final emptyKeys = filteredKeys.where((key) {
      final value = localeData[key] as String? ?? '';
      return value.isEmpty;
    }).length;
    final filledKeys = totalKeys - emptyKeys;

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
          if (emptyKeys > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    '$emptyKeys empty',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalKeys keys${filledKeys > 0 ? ' ($filledKeys filled)' : ''}',
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
    final bool isEmpty = value.isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isEmpty ? Colors.orange[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEmpty ? Icons.warning : Icons.key,
                  size: 16,
                  color: isEmpty
                      ? Colors.orange[700]
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Translation Key:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'EMPTY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
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
                  isEmpty ? Icons.edit : Icons.translate,
                  size: 16,
                  color: isEmpty
                      ? Colors.orange[700]
                      : Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isEmpty
                      ? 'Translation Value (REQUIRED):'
                      : 'Translation Value:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isEmpty
                        ? Colors.orange[700]
                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                hintText: isEmpty
                    ? '⚠️ This translation is missing - please fill it in'
                    : 'Enter translation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isEmpty ? Colors.orange[300]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isEmpty
                        ? Colors.orange[500]!
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
                fillColor: isEmpty ? Colors.orange[25] : null,
                filled: isEmpty,
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
