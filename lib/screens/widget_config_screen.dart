import 'package:flutter/material.dart';
import '../models/widget_config_model.dart';
import '../models/collection_model.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../widgets/widget_preview.dart';

class WidgetConfigScreen extends StatefulWidget {
  final WidgetConfig widgetConfig;
  final StorageService storageService;
  final WidgetService widgetService;

  const WidgetConfigScreen({
    super.key,
    required this.widgetConfig,
    required this.storageService,
    required this.widgetService,
  });

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  late WidgetConfig _config;
  late AppearanceConfig _appearance;
  List<Collection> _collections = [];
  Collection? _selectedCollection;

  @override
  void initState() {
    super.initState();
    _config = widget.widgetConfig;
    _appearance = _config.appearance;
    _collections = widget.storageService.getAllCollections();
    _selectedCollection = widget.storageService.getCollection(_config.collectionId);
  }

  void _updateAppearance(AppearanceConfig newAppearance) {
    setState(() {
      _appearance = newAppearance;
      _config.appearance = newAppearance;
    });
    _saveConfig();
  }

  void _updateTheme(String theme) {
    AppearanceConfig newAppearance;
    switch (theme) {
      case 'light':
        newAppearance = AppearanceConfig.light();
        break;
      case 'dark':
        newAppearance = AppearanceConfig.dark();
        break;
      default:
        newAppearance = _appearance;
        break;
    }
    newAppearance.fontSize = _appearance.fontSize;
    newAppearance.alignment = _appearance.alignment;
    _updateAppearance(newAppearance);
  }

  void _updateFontSize(double size) {
    _appearance.fontSize = size;
    _updateAppearance(_appearance);
  }

  void _updateTextColor(Color color) {
    _appearance.textColor = color.toARGB32();
    _updateAppearance(_appearance);
  }

  void _updateBackgroundColor(Color color) {
    _appearance.background = color.toARGB32();
    _updateAppearance(_appearance);
  }

  void _updateAlignment(TextAlignment alignment) {
    _appearance.alignment = alignment;
    _updateAppearance(_appearance);
  }

  void _updateSizeCategory(SizeCategory size) {
    setState(() {
      _config.sizeCategory = size;
    });
    _saveConfig();
  }

  void _updateCollection(Collection? collection) {
    if (collection != null) {
      setState(() {
        _selectedCollection = collection;
        _config.collectionId = collection.id;
      });
      _saveConfig();
    }
  }

  Future<void> _saveConfig() async {
    await widget.storageService.updateWidgetConfig(_config);
    await widget.widgetService.syncWidgetData(_config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Widget'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Preview
            _buildPreview(),
            const SizedBox(height: 24),

            // Collection Selector
            _buildCollectionSelector(),
            const SizedBox(height: 16),

            // Theme Presets
            _buildThemePresets(),
            const SizedBox(height: 16),

            // Font Size
            _buildFontSizeSlider(),
            const SizedBox(height: 16),

            // Colors
            _buildColorPickers(),
            const SizedBox(height: 16),

            // Alignment
            _buildAlignmentSelector(),
            const SizedBox(height: 16),

            // Size Category
            _buildSizeSelector(),
            const SizedBox(height: 16),

            // Show Progress Toggle
            _buildShowProgressToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        WidgetPreview(
          config: _config,
          collection: _selectedCollection,
          storageService: widget.storageService,
        ),
      ],
    );
  }

  Widget _buildCollectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Collection>(
          initialValue: _selectedCollection,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _collections.map((collection) {
            return DropdownMenuItem(
              value: collection,
              child: Text(collection.name),
            );
          }).toList(),
          onChanged: _updateCollection,
        ),
      ],
    );
  }

  Widget _buildThemePresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildThemeButton('Light', 'light', Icons.light_mode),
            const SizedBox(width: 8),
            _buildThemeButton('Dark', 'dark', Icons.dark_mode),
            const SizedBox(width: 8),
            _buildThemeButton('Custom', 'custom', Icons.palette),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeButton(String label, String theme, IconData icon) {
    final isSelected = _appearance.theme == theme;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _updateTheme(theme),
        icon: Icon(
          icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Font Size',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${_appearance.fontSize.round()}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        Slider(
          value: _appearance.fontSize,
          min: 12,
          max: 32,
          divisions: 20,
          onChanged: _updateFontSize,
        ),
      ],
    );
  }

  Widget _buildColorPickers() {
    return Row(
      children: [
        Expanded(
          child: _buildColorPicker(
            'Text Color',
            Color(_appearance.textColor),
            _updateTextColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildColorPicker(
            'Background',
            Color(_appearance.background),
            _updateBackgroundColor,
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(String label, Color currentColor, Function(Color) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showColorPicker(currentColor, onChanged),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: currentColor,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker(Color currentColor, Function(Color) onChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Colors.black,
            Colors.white,
            Colors.grey,
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.purple,
            Colors.teal,
            Colors.pink,
          ].map((color) {
            return GestureDetector(
              onTap: () {
                onChanged(color);
                Navigator.of(context).pop();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(
                    color: currentColor.toARGB32() == color.toARGB32()
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    width: currentColor.toARGB32() == color.toARGB32() ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAlignmentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alignment',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAlignmentButton('Left', TextAlignment.left, Icons.format_align_left),
            const SizedBox(width: 8),
            _buildAlignmentButton('Center', TextAlignment.center, Icons.format_align_center),
            const SizedBox(width: 8),
            _buildAlignmentButton('Right', TextAlignment.right, Icons.format_align_right),
          ],
        ),
      ],
    );
  }

  Widget _buildAlignmentButton(String label, TextAlignment alignment, IconData icon) {
    final isSelected = _appearance.alignment == alignment;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _updateAlignment(alignment),
        icon: Icon(
          icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildShowProgressToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Indicator',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Show n/total on widget'),
          subtitle: const Text('Display current position in collection'),
          value: _config.showProgress,
          onChanged: (value) {
            setState(() {
              _config.showProgress = value;
            });
            _saveConfig();
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Widget Size',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateSizeCategory(SizeCategory.small),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _config.sizeCategory == SizeCategory.small
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    width: _config.sizeCategory == SizeCategory.small ? 2 : 1,
                  ),
                ),
                child: Text(
                  'Small',
                  style: TextStyle(
                    color: _config.sizeCategory == SizeCategory.small
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateSizeCategory(SizeCategory.medium),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _config.sizeCategory == SizeCategory.medium
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    width: _config.sizeCategory == SizeCategory.medium ? 2 : 1,
                  ),
                ),
                child: Text(
                  'Medium',
                  style: TextStyle(
                    color: _config.sizeCategory == SizeCategory.medium
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
