import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/kitchen_models.dart';
import '../../services/ai_kitchen_service.dart';
import '../../state/kitchen_store.dart';
import '../../theme/crisper_theme.dart';

class AiScannerSheet extends ConsumerStatefulWidget {
  const AiScannerSheet({super.key, this.initialMode = 'fridge'});

  final String initialMode;

  @override
  ConsumerState<AiScannerSheet> createState() => _AiScannerSheetState();
}

class _AiScannerSheetState extends ConsumerState<AiScannerSheet> {
  late String _mode = widget.initialMode; // 'fridge' | 'receipt' | 'barcode'
  bool _isScanning = false;
  List<PantryItem> _detected = [];
  Uint8List? _capturedPreview;
  final TextEditingController _barcodeCtrl = TextEditingController(
    text: '4820000451123',
  );

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _runPhotoOrDemoScan({ImageSource? source}) async {
    Uint8List? bytes;
    if (source != null) {
      try {
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1280,
          imageQuality: 82,
        );
        if (file == null) return;
        bytes = await file.readAsBytes();
      } catch (_) {
        // On emulator without camera feed, seamlessly fall back to demo capture
      }
    }

    setState(() {
      _isScanning = true;
      _capturedPreview = bytes;
    });

    final apiKey = ref.read(kitchenProvider).settings.geminiApiKey;
    final items = await AiKitchenService.scanKitchenImage(
      imageBytes: bytes,
      presetType: _mode,
      apiKey: apiKey,
    );

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _detected = items;
    });
  }

  Future<void> _runBarcodeLookup() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _isScanning = true);
    final item = await AiKitchenService.lookupBarcode(code);
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _detected = [item, ..._detected];
    });
  }

  void _adjustDetectedAmount(int index, double factor) {
    final item = _detected[index];
    final step = item.unit == 'шт' || item.unit == 'уп' ? 1.0 : 50.0;
    final nextVal = (item.amountGramsOrPcs + (step * factor)).clamp(
      item.unit == 'шт' || item.unit == 'уп' ? 1.0 : 20.0,
      5000.0,
    );
    setState(() {
      _detected[index] = item.copyWith(amountGramsOrPcs: nextVal);
    });
  }

  void _confirmUncertain(int index) {
    final item = _detected[index];
    setState(() {
      _detected[index] = item.copyWith(
        name: item.name.replaceAll('?', ''),
        confidence: 0.99,
      );
    });
  }

  static String _pluralProducts(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return '$n продуктів';
    if (mod10 == 1) return '$n продукт';
    if (mod10 >= 2 && mod10 <= 4) return '$n продукти';
    return '$n продуктів';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Сканер Кухні',
                            style: CrisperTypography.headlineMd(p.ink),
                          ),
                          Text(
                            'Розпізнавання полиці холодильника, чека або штрих-коду',
                            style: CrisperTypography.bodySm(p.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: p.muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _ModeTab(
                      label: 'Холодильник',
                      icon: Icons.kitchen_outlined,
                      active: _mode == 'fridge',
                      onTap: () => setState(() => _mode = 'fridge'),
                    ),
                    const SizedBox(width: 8),
                    _ModeTab(
                      label: 'Чек',
                      icon: Icons.receipt_long_outlined,
                      active: _mode == 'receipt',
                      onTap: () => setState(() => _mode = 'receipt'),
                    ),
                    const SizedBox(width: 8),
                    _ModeTab(
                      label: 'Штрих-код',
                      icon: Icons.qr_code_scanner_rounded,
                      active: _mode == 'barcode',
                      onTap: () => setState(() => _mode = 'barcode'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (_mode == 'barcode') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Введіть або скануйте EAN-13 штрих-код (Open Food Facts)',
                              style: CrisperTypography.labelMd(p.ink),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _barcodeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: CrisperTypography.tabular(p.ink),
                                    decoration: InputDecoration(
                                      hintText: '4820000451123',
                                      filled: true,
                                      fillColor: p.surfaceLow,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: p.border),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.icon(
                                  onPressed:
                                      _isScanning ? null : _runBarcodeLookup,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: p.primaryAction,
                                    foregroundColor: p.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  icon: const Icon(Icons.search_rounded, size: 18),
                                  label: const Text('Знайти'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                ActionChip(
                                  label: const Text('Молоко (4820000451123)'),
                                  onPressed: () {
                                    _barcodeCtrl.text = '4820000451123';
                                    _runBarcodeLookup();
                                  },
                                ),
                                ActionChip(
                                  label: const Text('Barilla (8076809513753)'),
                                  onPressed: () {
                                    _barcodeCtrl.text = '8076809513753';
                                    _runBarcodeLookup();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Camera / Shelf Preview Card with AI Pins
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 175,
                              width: double.infinity,
                              child: _capturedPreview != null
                                  ? Image.memory(
                                      _capturedPreview!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      _mode == 'receipt'
                                          ? 'assets/images/img_10.jpg'
                                          : 'assets/images/img_07.jpg',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.15),
                                      Colors.black.withValues(alpha: 0.62),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_detected.isNotEmpty && !_isScanning) ...[
                              const Positioned(
                                top: 24,
                                left: 26,
                                child: _DetectionPin(label: '✓ Печериці 96%'),
                              ),
                              const Positioned(
                                top: 64,
                                right: 24,
                                child: _DetectionPin(label: '✓ Вершки 93%'),
                              ),
                            ],
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 12,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _isScanning
                                          ? null
                                          : () => _runPhotoOrDemoScan(),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: p.primaryAction,
                                        foregroundColor: p.onPrimary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      icon: _isScanning
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        _isScanning
                                            ? 'AI аналізує фото...'
                                            : (_mode == 'receipt'
                                                ? 'AI Скан демо-чека'
                                                : 'AI Скан полиці'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: 'Зробити фото камерою',
                                    onPressed: _isScanning
                                        ? null
                                        : () => _runPhotoOrDemoScan(
                                              source: ImageSource.camera,
                                            ),
                                    icon: const Icon(Icons.camera_alt_outlined),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    tooltip: 'Обрати з галереї',
                                    onPressed: _isScanning
                                        ? null
                                        : () => _runPhotoOrDemoScan(
                                              source: ImageSource.gallery,
                                            ),
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (_detected.isEmpty && !_isScanning)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: p.surfaceLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 34,
                              color: p.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Натисніть «AI Скан полиці», зробіть фото або введіть штрих-код',
                              textAlign: TextAlign.center,
                              style: CrisperTypography.titleMd(p.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AI за кілька секунд розпізнає продукти, вагу та орієнтовний термін свіжості.',
                              textAlign: TextAlign.center,
                              style: CrisperTypography.bodySm(p.muted),
                            ),
                          ],
                        ),
                      ),
                    if (_detected.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Знайдено ${_pluralProducts(_detected.length)}',
                            style: CrisperTypography.headlineSm(p.ink),
                          ),
                          Text(
                            'Свайп вліво — прибрати',
                            style: CrisperTypography.bodySm(p.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_detected.length, (idx) {
                        final item = _detected[idx];
                        final uncertain = (item.confidence ?? 1.0) < 0.75;
                        return Dismissible(
                          key: ValueKey('scan_${item.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 18),
                            decoration: BoxDecoration(
                              color: p.peachChipBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: p.terracotta,
                            ),
                          ),
                          onDismissed: (_) {
                            setState(() => _detected.removeAt(idx));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: uncertain ? p.terracotta : p.border,
                              width: uncertain ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: uncertain
                                      ? p.peachChipBg
                                      : p.sageChipBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.category.icon,
                                  size: 20,
                                  color: uncertain
                                      ? p.terracotta
                                      : p.sageChipText,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: CrisperTypography.titleMd(p.ink),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '~${item.daysLeftBadge}',
                                          style: CrisperTypography.bodySm(
                                            p.muted,
                                          ),
                                        ),
                                        if (uncertain) ...[
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _confirmUncertain(idx),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: p.peachChipBg,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Підтвердити?',
                                                style:
                                                    CrisperTypography.labelSm(
                                                      p.peachChipText,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _adjustDetectedAmount(idx, -1),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                              ),
                              Text(
                                '${item.amountGramsOrPcs.toInt()} ${item.unit}',
                                style: CrisperTypography.tabular(p.ink),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _adjustDetectedAmount(idx, 1),
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() => _detected.removeAt(idx));
                                },
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ],
                  ],
                ),
              ),
              if (_detected.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          final clean = _detected
                              .map(
                                (e) => e.copyWith(
                                  name: e.name.replaceAll('?', ''),
                                ),
                              )
                              .toList();
                          ref
                              .read(kitchenProvider.notifier)
                              .addOrMergePantryItems(clean);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Додано ${clean.length} продукти у ваш холодильник!',
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primaryAction,
                          foregroundColor: p.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          'Додати ${_detected.length} у холодильник',
                          style: CrisperTypography.labelLg(p.onPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? p.primaryAction : p.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? p.primaryAction : p.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? p.onPrimary : p.muted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CrisperTypography.labelMd(
                    active ? p.onPrimary : p.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectionPin extends StatelessWidget {
  const _DetectionPin({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: CrisperTypography.labelSm(const Color(0xFF144227)),
      ),
    );
  }
}
