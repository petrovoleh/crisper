import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_kitchen_service.dart';
import '../../services/social_recipe_extractor.dart';
import '../../state/kitchen_store.dart';
import '../../theme/crisper_theme.dart';

class SocialImportSheet extends ConsumerStatefulWidget {
  const SocialImportSheet({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<SocialImportSheet> createState() => _SocialImportSheetState();
}

class _SocialImportSheetState extends ConsumerState<SocialImportSheet> {
  late final TextEditingController _urlCtrl = TextEditingController(
    text: widget.initialUrl ?? '',
  );
  bool _isExtracting = false;
  String? _errorHint;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _urlCtrl.text = data.text!.trim();
        _errorHint = null;
      });
    }
  }

  Future<void> _extractRecipe() async {
    final text = _urlCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isExtracting = true;
      _errorHint = null;
    });

    try {
      final st = ref.read(kitchenProvider);
      final recipe = await AiKitchenService.importRecipeFromSocialLink(
        urlOrText: text,
        currentPantry: st.pantry,
        apiKey: st.settings.geminiApiKey,
      );
      if (!mounted) return;
      ref.read(kitchenProvider.notifier).addNewRecipe(recipe);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Рецепт «${recipe.title}» успішно розібрано!'),
        ),
      );
    } on RecipeImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorHint = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorHint =
            'Не вдалося завантажити сторінку (перевірте інтернет або вставте текст рецепта прямо сюди).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.sageChipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_link_rounded,
                    color: p.sageChipText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Імпорт рецепта із соцмереж',
                        style: CrisperTypography.headlineSm(p.ink),
                      ),
                       Text(
                         'TikTok • Instagram Reels • YouTube Shorts • Сайти',
                         style: CrisperTypography.bodySm(p.muted),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 12),
             Container(
               padding: const EdgeInsets.symmetric(
                 horizontal: 12,
                 vertical: 9,
               ),
               decoration: BoxDecoration(
                 color: p.sageChipBg.withValues(alpha: p.isDark ? 0.55 : 0.65),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Row(
                 children: [
                   Icon(
                     Icons.graphic_eq_rounded,
                     size: 18,
                     color: p.sageChipText,
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       'Навіть без опису! Сам читає розшифровку голосу/субтитри відео й відновлює інгредієнти.',
                       style: CrisperTypography.bodySm(p.ink).copyWith(
                         fontWeight: FontWeight.w500,
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 12),
             TextField(
               controller: _urlCtrl,
               maxLines: 4,
               minLines: 2,
               style: CrisperTypography.bodyMd(p.ink),
               onChanged: (_) {
                 if (_errorHint != null) setState(() => _errorHint = null);
               },
               decoration: InputDecoration(
                 hintText:
                     'Вставте посилання з TikTok, Instagram Reels, YouTube / Shorts, кулінарного сайту або текст рецепта...',
                 hintStyle: CrisperTypography.bodySm(p.muted),
                filled: true,
                fillColor: p.card,
                suffixIcon: IconButton(
                  tooltip: 'Вставити з буфера',
                  onPressed: _pasteClipboard,
                  icon: Icon(Icons.content_paste_rounded, color: p.primary),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
            ),
            if (_errorHint != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.peachChipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: p.peachChipText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorHint!,
                        style: CrisperTypography.bodySm(p.peachChipText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Швидка перевірка у 1 дотик (реальні кулінарні відео):',
              style: CrisperTypography.labelSm(p.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(
                    Icons.music_note_rounded,
                    size: 16,
                    color: p.sageChipText,
                  ),
                  backgroundColor: p.sageChipBg,
                  side: BorderSide.none,
                  label: Text(
                    'TikTok: Ліниві вареники',
                    style: CrisperTypography.labelSm(p.sageChipText),
                  ),
                  onPressed: () {
                    setState(() {
                      _urlCtrl.text = 'https://vm.tiktok.com/ZN8uP1BfB/';
                      _errorHint = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.camera_alt_outlined,
                    size: 16,
                    color: p.peachChipText,
                  ),
                  backgroundColor: p.peachChipBg,
                  side: BorderSide.none,
                  label: Text(
                    'Instagram Reels: Сирники',
                    style: CrisperTypography.labelSm(p.peachChipText),
                  ),
                  onPressed: () {
                    setState(() {
                      _urlCtrl.text =
                          'https://www.instagram.com/reel/Df_0q0gIml6/';
                      _errorHint = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.mic_none_rounded,
                    size: 16,
                    color: p.terracotta,
                  ),
                  backgroundColor: p.peachChipBg,
                  side: BorderSide.none,
                  label: Text(
                    'Shorts без опису (лише голос)',
                    style: CrisperTypography.labelSm(p.peachChipText),
                  ),
                  onPressed: () {
                    setState(() {
                      _urlCtrl.text =
                          'https://www.youtube.com/shorts/AIV-vF3Epy4';
                      _errorHint = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.ondemand_video_rounded,
                    size: 16,
                    color: p.primary,
                  ),
                  backgroundColor: p.card,
                  side: BorderSide(color: p.border),
                  label: Text(
                    'YouTube Shorts: Сирники',
                    style: CrisperTypography.labelSm(p.ink),
                  ),
                  onPressed: () {
                    setState(() {
                      _urlCtrl.text =
                          'https://www.youtube.com/shorts/vC8qJNoA0zI';
                      _errorHint = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.article_outlined,
                    size: 16,
                    color: p.muted,
                  ),
                  backgroundColor: p.card,
                  side: BorderSide(color: p.border),
                  label: Text(
                    'Текст рецепта',
                    style: CrisperTypography.labelSm(p.ink),
                  ),
                  onPressed: () {
                    setState(() {
                      _urlCtrl.text =
                          'Ніжні домашні сирники\n- сир кисломолочний 350 г\n- яйце 1 шт\n- цукор 1 ст. л.\n- борошно 3 ст. л.\nЗмішайте всі інгредієнти та обсмажте на середньому вогні по 4 хв з кожного боку.';
                      _errorHint = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isExtracting ? null : _extractRecipe,
                style: FilledButton.styleFrom(
                  backgroundColor: p.primaryAction,
                  foregroundColor: p.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isExtracting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _isExtracting
                      ? 'Завантажуємо опис та розбираємо рецепт...'
                      : 'Розібрати рецепт та звірити з холодильником',
                  textAlign: TextAlign.center,
                  style: CrisperTypography.labelLg(p.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
