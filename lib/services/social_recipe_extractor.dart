import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/kitchen_models.dart';
import 'ingredient_normalizer.dart';

class RecipeImportException implements Exception {
  const RecipeImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SocialPagePayload {
  const SocialPagePayload({
    required this.source,
    required this.resolvedUrl,
    required this.rawText,
    this.pageTitle,
    this.authorHandle,
    this.coverImageUrl,
    this.durationSeconds,
    this.ldJsonRecipe,
    this.transcript = '',
    this.onScreenText = '',
    this.videoUrl,
  });

  final RecipeSource source;
  final String resolvedUrl;

  /// Author caption / description (+ user notes).
  final String rawText;
  final String? pageTitle;
  final String? authorHandle;
  final String? coverImageUrl;
  final int? durationSeconds;
  final Map<String, dynamic>? ldJsonRecipe;

  /// Spoken subtitles (TikTok ASR / YouTube captions).
  final String transcript;

  /// Text recognized from the video frames (on-screen titles, overlays).
  final String onScreenText;

  /// Direct video URL (TikTok mp4) or YouTube watch URL for video understanding.
  final String? videoUrl;

  /// Description → subtitles → on-screen text, in priority order.
  String get combinedText => [
    rawText,
    transcript,
    onScreenText,
  ].where((s) => s.trim().isNotEmpty).join('\n');

  SocialPagePayload copyWith({String? onScreenText, String? transcript}) {
    return SocialPagePayload(
      source: source,
      resolvedUrl: resolvedUrl,
      rawText: rawText,
      pageTitle: pageTitle,
      authorHandle: authorHandle,
      coverImageUrl: coverImageUrl,
      durationSeconds: durationSeconds,
      ldJsonRecipe: ldJsonRecipe,
      transcript: transcript ?? this.transcript,
      onScreenText: onScreenText ?? this.onScreenText,
      videoUrl: videoUrl,
    );
  }
}

class SocialRecipeExtractor {
  static const String _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  static const String _androidYoutubeUa =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip';
  static const String _facebookCrawlerUa =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
  static const String _telegramCrawlerUa = 'TelegramBot (like TwitterBot)';

  static RecipeSource detectSource(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('tiktok.com')) return RecipeSource.tiktok;
    if (lower.contains('instagram.com') ||
        lower.contains('instagr.am') ||
        lower.contains('threads.net')) {
      return RecipeSource.instagram;
    }
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return RecipeSource.youtube;
    }
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return RecipeSource.web;
    }
    return RecipeSource.curated;
  }

  static String? extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
    return match?.group(0);
  }

  /// Extracts an 11-character YouTube video ID from `watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`, `/live/`, or `/v/` URLs.
  static String? extractYouTubeVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri != null) {
      final host = uri.host.toLowerCase();
      if (host.contains('youtu.be')) {
        final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        if (_isValidYouTubeId(seg)) return seg;
      }
      if (host.contains('youtube.com')) {
        final vParam = uri.queryParameters['v'];
        if (vParam != null && _isValidYouTubeId(vParam)) return vParam;

        final segs = uri.pathSegments;
        for (int i = 0; i < segs.length - 1; i++) {
          final prefix = segs[i].toLowerCase();
          if (prefix == 'shorts' ||
              prefix == 'embed' ||
              prefix == 'live' ||
              prefix == 'v') {
            final candidate = segs[i + 1];
            if (_isValidYouTubeId(candidate)) return candidate;
          }
        }
      }
    }

    final fallback = RegExp(
      r'(?:youtu\.be/|youtube\.com/(?:shorts/|embed/|live/|v/|watch\?(?:[^#\s]*&)?v=))([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])',
      caseSensitive: false,
    ).firstMatch(url);
    return fallback?.group(1);
  }

  static bool _isValidYouTubeId(String value) {
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value);
  }

  /// Extracts the shortcode from Instagram Reels or Post URLs (`/reel/<id>`, `/reels/<id>`, `/p/<id>`, `/tv/<id>`, or `/<user>/reel/<id>`).
  static String? extractInstagramShortcode(String url) {
    final match = RegExp(
      r'(?:instagram\.com|instagr\.am)/(?:[A-Za-z0-9._]+/)?(?:reel|reels|p|tv)/([A-Za-z0-9_-]{5,24})',
      caseSensitive: false,
    ).firstMatch(url);
    return match?.group(1);
  }

  /// Unwraps Instagram meta descriptions/titles (`"90 likes, 0 comments - user on Date: \"...\"."` or `"Author on Instagram: \"...\""`)
  /// and unescapes HTML entities into a clean recipe caption.
  static String cleanInstagramCaption(String rawMeta) {
    final cleaned = _unescapeHtml(rawMeta).trim();
    if (cleaned.isEmpty) return '';

    // Pattern 1: "90 likes, 0 comments - username [on] Month Day, Year: "CAPTION"."
    final likesWrapper = RegExp(
      r'^[\d,.kmKM\s]+likes?,\s*[\d,.kmKM\s]+comments?\s*-\s*[A-Za-z0-9._]+\s+(?:on\s+)?[^:]{3,40}:\s*[«"“]([\s\S]+?)[»"”][.\s]*$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (likesWrapper != null) {
      return likesWrapper.group(1)!.trim();
    }

    // Pattern 2: "... on Instagram: "CAPTION"" or "... в Instagram: «CAPTION»"
    final igWrapper = RegExp(
      r'^[^\n]{1,140}?(?:on|в|у)\s+Instagram:\s*[«"“]([\s\S]+?)[»"”][.\s]*$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (igWrapper != null) {
      return igWrapper.group(1)!.trim();
    }

    // Pattern 3: Generic colon + quoted caption wrapper
    final genericQuote = RegExp(
      r':\s*[«"“]([\s\S]+?)[»"”][.\s]*$',
    ).firstMatch(cleaned);
    if (genericQuote != null && cleaned.indexOf(':') < 140) {
      return genericQuote.group(1)!.trim();
    }

    return cleaned;
  }

  /// Extracts `@username` from Instagram meta tags or profile-scoped URLs.
  static String? extractInstagramAuthor({
    String? ogDescription,
    String? ogTitle,
    String? url,
  }) {
    for (final src in [ogDescription, ogTitle]) {
      if (src == null || src.isEmpty) continue;
      final unescaped = _unescapeHtml(src);

      final likesMatch = RegExp(
        r'comments?\s*-\s*@?([A-Za-z0-9._]{2,30})\b',
        caseSensitive: false,
      ).firstMatch(unescaped);
      if (likesMatch != null) {
        return '@${likesMatch.group(1)!}';
      }

      final parenMatch = RegExp(
        r'\(@([A-Za-z0-9._]{2,30})\)',
      ).firstMatch(unescaped);
      if (parenMatch != null) {
        return '@${parenMatch.group(1)!}';
      }
    }

    if (url != null) {
      final pathMatch = RegExp(
        r'instagram\.com/([A-Za-z0-9._]{2,30})/(?:reel|reels|p|tv)/',
        caseSensitive: false,
      ).firstMatch(url);
      if (pathMatch != null) {
        final candidate = pathMatch.group(1)!;
        const reserved = {
          'reel',
          'reels',
          'p',
          'tv',
          'stories',
          'explore',
          'share',
        };
        if (!reserved.contains(candidate.toLowerCase())) {
          return '@$candidate';
        }
      }
    }
    return null;
  }

  /// Fetches real caption, description, subtitles, author, cover image, or Schema.org Recipe JSON from any social/web URL.
  static Future<SocialPagePayload> fetchPayload(String input) async {
    final trimmed = input.trim();
    final url = extractFirstUrl(trimmed);
    if (url == null) {
      return SocialPagePayload(
        source: RecipeSource.curated,
        resolvedUrl: '',
        rawText: trimmed,
      );
    }

    final source = detectSource(url);
    final extraUserNotes = trimmed.replaceAll(url, '').trim();

    if (source == RecipeSource.tiktok) {
      final tk = await _fetchTikTok(url, extraUserNotes);
      if (tk != null) return tk;
    } else if (source == RecipeSource.youtube) {
      final yt = await _fetchYouTube(url, extraUserNotes);
      if (yt != null) return yt;
    } else if (source == RecipeSource.instagram) {
      final ig = await _fetchInstagram(url, extraUserNotes);
      if (ig != null) return ig;
    }

    return _fetchGenericHtmlOrSocial(url, source, extraUserNotes);
  }

  static Future<SocialPagePayload?> _fetchTikTok(
    String url,
    String extraNotes,
  ) async {
    // tikwm (clean JSON + direct mp4) and the TikTok page (subtitleInfos with ASR captions) in parallel
    final results = await Future.wait([
      _fetchTikwmData(url),
      _fetchTikTokItemStruct(url),
    ]);
    final tikwm = results[0];
    final item = results[1];
    if (tikwm == null && item == null) return null;

    final video = item?['video'] as Map<String, dynamic>? ?? const {};
    final itemAuthor = item?['author'] as Map<String, dynamic>? ?? const {};
    final tikwmAuthor = tikwm?['author'] as Map<String, dynamic>?;

    final tikwmDesc = (tikwm?['title'] as String?)?.trim() ?? '';
    final itemDesc = (item?['desc'] as String?)?.trim() ?? '';
    final desc = itemDesc.length > tikwmDesc.length ? itemDesc : tikwmDesc;

    final rawCover =
        (tikwm?['cover'] as String?) ??
        (tikwm?['origin_cover'] as String?) ??
        (video['cover'] as String?) ??
        (video['originCover'] as String?);
    final inlinedCover = await _inlineCoverImage(
      rawCover,
      referer: 'https://www.tiktok.com/',
    );
    final uniqueId =
        (tikwmAuthor?['unique_id'] as String?) ??
        (itemAuthor['uniqueId'] as String?);
    final duration =
        (tikwm?['duration'] as num?)?.toInt() ??
        (video['duration'] as num?)?.toInt();

    // Spoken subtitles (TikTok auto-captions in both subtitleInfos and claInfo.captionInfos)
    String transcript = '';
    final claCaptions =
        (video['claInfo'] as Map<String, dynamic>?)?['captionInfos']
            as List<dynamic>?;
    final combinedTrackList = <dynamic>[
      ...?video['subtitleInfos'] as List<dynamic>?,
      ...?claCaptions,
    ];
    if (combinedTrackList.isNotEmpty) {
      transcript = await _downloadTikTokSubtitles(combinedTrackList);
    }

    // Direct no-watermark mp4 for on-screen text recognition
    final playUrl =
        (tikwm?['play'] as String?) ?? (tikwm?['hdplay'] as String?);

    final combined = [
      desc,
      if (extraNotes.isNotEmpty) extraNotes,
    ].where((s) => s.isNotEmpty).join('\n');

    if (combined.isEmpty && transcript.isEmpty && playUrl == null) {
      return null;
    }

    return SocialPagePayload(
      source: RecipeSource.tiktok,
      resolvedUrl: url,
      rawText: combined,
      authorHandle: uniqueId != null ? '@$uniqueId' : null,
      coverImageUrl: inlinedCover ?? rawCover,
      durationSeconds: duration,
      transcript: transcript,
      videoUrl: playUrl,
    );
  }

  static Future<Map<String, dynamic>?> _fetchTikwmData(String url) async {
    try {
      final apiUri = Uri.parse(
        'https://www.tikwm.com/api/?url=${Uri.encodeComponent(url)}',
      );
      final resp = await http
          .get(apiUri, headers: {'User-Agent': _desktopUa})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final root =
            jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true))
                as Map<String, dynamic>;
        return root['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchTikTokItemStruct(
    String url,
  ) async {
    try {
      final resp = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': _desktopUa,
              'Accept-Language': 'uk-UA,uk;q=0.9,ru;q=0.8,en;q=0.7',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
        final match = RegExp(
          r'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
          dotAll: true,
        ).firstMatch(html);
        if (match != null) {
          final jsonMap = jsonDecode(match.group(1)!) as Map<String, dynamic>;
          final scope =
              jsonMap['__DEFAULT_SCOPE__'] as Map<String, dynamic>? ?? {};
          final detail =
              scope['webapp.video-detail'] as Map<String, dynamic>? ?? {};
          final itemInfo = detail['itemInfo'] as Map<String, dynamic>? ?? {};
          return itemInfo['itemStruct'] as Map<String, dynamic>?;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Picks the best TikTok subtitle track (Ukrainian → Russian → English, original ASR over machine translation)
  /// and returns clean prose.
  static Future<String> _downloadTikTokSubtitles(
    List<dynamic> subtitleInfos,
  ) async {
    String? resolveTrackUrl(Map<String, dynamic> t) {
      for (final k in ['Url', 'url']) {
        final v = t[k];
        if (v is String && v.startsWith('http')) return v;
      }
      for (final k in ['UrlList', 'urlList']) {
        final v = t[k];
        if (v is List && v.isNotEmpty && v.first is String) {
          final first = v.first as String;
          if (first.startsWith('http')) return first;
        }
      }
      return null;
    }

    final tracks = subtitleInfos.whereType<Map<String, dynamic>>().where(
      (t) => resolveTrackUrl(t) != null,
    );
    if (tracks.isEmpty) return '';

    int score(Map<String, dynamic> t) {
      final lang =
          ((t['LanguageCodeName'] ?? t['languageCodeName'] ?? '') as String)
              .toLowerCase();
      final src =
          ((t['Source'] ?? t['source'] ?? '') as String).toUpperCase();
      int s = 0;
      // Original speech recognition is more faithful than machine translation
      if (src.contains('ASR') || t['isAutoGenerated'] == true) s += 100;
      if (lang.startsWith('ukr') || lang.startsWith('uk')) {
        s += 30;
      } else if (lang.startsWith('rus') || lang.startsWith('ru')) {
        s += 20;
      } else if (lang.startsWith('eng') || lang.startsWith('en')) {
        s += 10;
      }
      return s;
    }

    final sorted = tracks.toList()..sort((a, b) => score(b) - score(a));
    for (final track in sorted.take(2)) {
      final trackUrl = resolveTrackUrl(track);
      if (trackUrl == null) continue;
      try {
        final resp = await http
            .get(
              Uri.parse(trackUrl),
              headers: {
                'User-Agent': _desktopUa,
                'Referer': 'https://www.tiktok.com/',
              },
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final text = parseWebVtt(
            utf8.decode(resp.bodyBytes, allowMalformed: true),
          );
          if (text.isNotEmpty) return text;
        }
      } catch (_) {}
    }
    return '';
  }

  /// Converts a WebVTT subtitle file into newline-separated cues (no timestamps, no duplicates).
  static String parseWebVtt(String vtt) {
    if (vtt.trim().isEmpty) return '';
    final lines = <String>[];
    final timing = RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?[.,]\d{3}\s*-->');
    for (final raw in vtt.split(RegExp(r'\r?\n'))) {
      final l = raw.trim();
      if (l.isEmpty ||
          l == 'WEBVTT' ||
          l.startsWith('WEBVTT ') ||
          l.startsWith('NOTE') ||
          l.startsWith('STYLE') ||
          timing.hasMatch(l) ||
          RegExp(r'^\d+$').hasMatch(l)) {
        continue;
      }
      final clean = _unescapeHtml(l.replaceAll(RegExp(r'<[^>]+>'), ''))
          .replaceAll(
            RegExp(
              r'\[(?:музика|музыка|music|applause|оплески|пение|смех|сміх)\]',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (clean.isEmpty) continue;
      if (lines.isNotEmpty && lines.last == clean) continue;
      lines.add(clean);
    }
    return lines.join('\n');
  }

  static Future<String?> _inlineCoverImage(
    String? imageUrl, {
    String? referer,
  }) async {
    if (imageUrl == null) return null;
    final cleanUrl = _unescapeHtml(imageUrl).trim();
    if (!cleanUrl.startsWith('http')) return null;

    try {
      final resp = await http
          .get(
            Uri.parse(cleanUrl),
            headers: {
              'User-Agent': _desktopUa,
              'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
              'Referer': ?referer,
            },
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200 &&
          resp.bodyBytes.isNotEmpty &&
          resp.bodyBytes.length <= 450000) {
        final ct = (resp.headers['content-type'] ?? '').toLowerCase();
        final mime = ct.contains('png')
            ? 'image/png'
            : (ct.contains('webp') ? 'image/webp' : 'image/jpeg');
        return 'data:$mime;base64,${base64Encode(resp.bodyBytes)}';
      }
    } catch (_) {}
    return null;
  }

  static Future<SocialPagePayload?> _fetchYouTube(
    String url,
    String extraNotes,
  ) async {
    String? videoId = extractYouTubeVideoId(url);
    final watchUrl = videoId != null
        ? 'https://www.youtube.com/watch?v=$videoId'
        : url;

    String title = '';
    String shortDesc = '';
    String? author;
    int? durationSeconds;
    List<dynamic>? webCaptionTracks;

    // 1. Primary: Fetch watch page with CONSENT cookie and parse ytInitialPlayerResponse
    try {
      final resp = await http
          .get(
            Uri.parse(watchUrl),
            headers: {
              'User-Agent': _desktopUa,
              'Cookie': 'CONSENT=YES+cb.20210328-17-p0.en+FX+999; SOCS=CAI',
              'Accept-Language': 'uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7',
            },
          )
          .timeout(const Duration(seconds: 9));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
        final playerJson = _extractBalancedJsonObject(
          html,
          'ytInitialPlayerResponse',
        );
        if (playerJson != null) {
          final details =
              playerJson['videoDetails'] as Map<String, dynamic>? ?? {};
          title = (details['title'] as String?)?.trim() ?? '';
          shortDesc = (details['shortDescription'] as String?)?.trim() ?? '';
          author = (details['author'] as String?)?.trim();
          videoId ??= (details['videoId'] as String?)?.trim();
          durationSeconds = int.tryParse(
            (details['lengthSeconds'] ?? '').toString(),
          );
          webCaptionTracks =
              (((playerJson['captions']
                          as Map<
                            String,
                            dynamic
                          >?)?['playerCaptionsTracklistRenderer']
                      as Map<String, dynamic>?)?['captionTracks'])
                  as List<dynamic>?;
        }
      }
    } catch (_) {}

    // 2. Check if we need spoken subtitles (captionTracks) or Innertube player fallback
    String transcript = '';
    final needsSubtitles = !_hasEnoughExplicitIngredients(shortDesc);

    if (needsSubtitles &&
        webCaptionTracks != null &&
        webCaptionTracks.isNotEmpty) {
      transcript = await _downloadBestCaptionTrack(
        webCaptionTracks,
        userAgent: _desktopUa,
      );
    }

    if ((title.isEmpty || (needsSubtitles && transcript.isEmpty)) &&
        videoId != null) {
      try {
        final innertubeResp = await http
            .post(
              Uri.parse(
                'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
              ),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': _androidYoutubeUa,
              },
              body: jsonEncode({
                'context': {
                  'client': {
                    'clientName': 'ANDROID',
                    'clientVersion': '20.10.38',
                    'androidSdkVersion': 34,
                    'hl': 'uk',
                    'gl': 'UA',
                  },
                },
                'videoId': videoId,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (innertubeResp.statusCode == 200 &&
            innertubeResp.bodyBytes.isNotEmpty) {
          final pj =
              jsonDecode(
                    utf8.decode(innertubeResp.bodyBytes, allowMalformed: true),
                  )
                  as Map<String, dynamic>;
          final vd = pj['videoDetails'] as Map<String, dynamic>? ?? {};
          if (title.isEmpty) {
            title = (vd['title'] as String?)?.trim() ?? '';
          }
          if (shortDesc.isEmpty) {
            shortDesc = (vd['shortDescription'] as String?)?.trim() ?? '';
          }
          author ??= (vd['author'] as String?)?.trim();
          durationSeconds ??= int.tryParse(
            (vd['lengthSeconds'] ?? '').toString(),
          );

          if (!_hasEnoughExplicitIngredients(shortDesc) && transcript.isEmpty) {
            final androidTracks =
                (((pj['captions']
                            as Map<
                              String,
                              dynamic
                            >?)?['playerCaptionsTracklistRenderer']
                        as Map<String, dynamic>?)?['captionTracks'])
                    as List<dynamic>?;
            if (androidTracks != null && androidTracks.isNotEmpty) {
              transcript = await _downloadBestCaptionTrack(
                androidTracks,
                userAgent: _androidYoutubeUa,
              );
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: noembed.com public oEmbed metadata
    String? noembedThumb;
    if (title.isEmpty) {
      try {
        final oembedUri = Uri.parse(
          'https://noembed.com/embed?url=${Uri.encodeComponent(watchUrl)}',
        );
        final oeResp = await http
            .get(oembedUri, headers: {'User-Agent': _desktopUa})
            .timeout(const Duration(seconds: 6));
        if (oeResp.statusCode == 200 && oeResp.bodyBytes.isNotEmpty) {
          final oe =
              jsonDecode(utf8.decode(oeResp.bodyBytes, allowMalformed: true))
                  as Map<String, dynamic>;
          title = (oe['title'] as String?)?.trim() ?? '';
          author ??= (oe['author_name'] as String?)?.trim();
          noembedThumb = (oe['thumbnail_url'] as String?)?.trim();
        }
      } catch (_) {}
    }

    final rawThumb = videoId != null
        ? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg'
        : noembedThumb;
    final inlinedThumb = await _inlineCoverImage(
      rawThumb,
      referer: 'https://www.youtube.com/',
    );

    final cleanedTitle = _cleanSocialVideoTitle(title);
    final combined = [
      if (cleanedTitle.isNotEmpty) cleanedTitle,
      if (shortDesc.isNotEmpty) shortDesc,
      if (extraNotes.isNotEmpty) extraNotes,
    ].where((s) => s.trim().isNotEmpty).join('\n');

    if (combined.isNotEmpty || transcript.isNotEmpty) {
      return SocialPagePayload(
        source: RecipeSource.youtube,
        resolvedUrl: url,
        rawText: combined,
        transcript: transcript,
        videoUrl: videoId != null ? watchUrl : null,
        pageTitle: cleanedTitle.isNotEmpty ? cleanedTitle : null,
        authorHandle: author != null && author.isNotEmpty
            ? (author.startsWith('@') ? author : author)
            : null,
        coverImageUrl: inlinedThumb ?? rawThumb,
        durationSeconds: durationSeconds,
      );
    }

    return null;
  }

  static Future<String> _downloadBestCaptionTrack(
    List<dynamic> captionTracks, {
    required String userAgent,
  }) async {
    Map<String, dynamic>? chosen;
    for (final pref in ['uk', 'en']) {
      for (final item in captionTracks) {
        if (item is Map<String, dynamic>) {
          final lang = (item['languageCode'] as String? ?? '').toLowerCase();
          if (lang == pref || lang.startsWith('$pref-')) {
            chosen = item;
            break;
          }
        }
      }
      if (chosen != null) break;
    }
    chosen ??= captionTracks.first is Map<String, dynamic>
        ? captionTracks.first as Map<String, dynamic>
        : null;

    final baseUrl = chosen?['baseUrl'] as String?;
    if (baseUrl == null || baseUrl.isEmpty) return '';

    try {
      final resp = await http
          .get(Uri.parse(baseUrl), headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final xml = utf8.decode(resp.bodyBytes, allowMalformed: true);
        return parseYouTubeTimedTextXml(xml);
      }
    } catch (_) {}
    return '';
  }

  /// Cleans YouTube `<timedtext>` XML (both format 1 `<text>` and format 3 `<p>/<s>`) into readable prose.
  static String parseYouTubeTimedTextXml(String xml) {
    if (xml.trim().isEmpty) return '';
    String text = xml
        .replaceAll(RegExp(r'</p>|</text>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _unescapeHtml(text)
        .replaceAll(
          RegExp(
            r'\[(?:музика|музыка|music|applause|оплески|пение)\]',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  static Future<SocialPagePayload?> _fetchInstagram(
    String url,
    String extraNotes,
  ) async {
    final shortcode = extractInstagramShortcode(url);
    String bestCaption = '';
    String? authorHandle;
    String? rawCoverUrl;
    String? pageTitle;

    // 1. Primary: Crawler SSR OpenGraph / Meta description (fast, untruncated full Reel & Post caption + CDN cover)
    final canonicalPath = url.toLowerCase().contains('/p/') ? 'p' : 'reel';
    final targetUrl = shortcode != null
        ? 'https://www.instagram.com/$canonicalPath/$shortcode/'
        : url;

    for (final crawlerUa in [_facebookCrawlerUa, _telegramCrawlerUa]) {
      if (bestCaption.length >= 30 && rawCoverUrl != null) break;
      try {
        final resp = await http
            .get(
              Uri.parse(targetUrl),
              headers: {
                'User-Agent': crawlerUa,
                'Accept-Language': 'uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7',
              },
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
          final ogTitle = _extractMetaContent(html, 'og:title');
          final ogDesc =
              _extractMetaContent(html, 'og:description') ??
              _extractMetaContent(html, 'description');
          final ogImage = _extractMetaContent(html, 'og:image');

          authorHandle ??= extractInstagramAuthor(
            ogDescription: ogDesc,
            ogTitle: ogTitle,
            url: url,
          );
          rawCoverUrl ??= ogImage != null ? _unescapeHtml(ogImage) : null;

          final cleanedFromDesc = ogDesc != null
              ? cleanInstagramCaption(ogDesc)
              : '';
          final cleanedFromTitle = ogTitle != null
              ? cleanInstagramCaption(ogTitle)
              : '';
          final candidate = cleanedFromDesc.length >= cleanedFromTitle.length
              ? cleanedFromDesc
              : cleanedFromTitle;

          if (candidate.length > bestCaption.length &&
              !_isGenericInstagramLoginPrompt(candidate)) {
            bestCaption = candidate;
          }
          if (ogTitle != null && pageTitle == null) {
            pageTitle = _unescapeHtml(ogTitle);
          }
        }
      } catch (_) {}
    }

    // 2. Fallback / Enrichment: Static captioned embed page (/p/$shortcode/embed/captioned/)
    if (shortcode != null && (bestCaption.length < 30 || rawCoverUrl == null)) {
      try {
        final embedUri = Uri.parse(
          'https://www.instagram.com/p/$shortcode/embed/captioned/',
        );
        final resp = await http
            .get(
              embedUri,
              headers: {
                'User-Agent': _desktopUa,
                'Accept-Language': 'uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7',
              },
            )
            .timeout(const Duration(seconds: 7));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
          final parsedEmbed = _parseInstagramEmbedHtml(html);
          if (parsedEmbed.caption.length > bestCaption.length) {
            bestCaption = parsedEmbed.caption;
          }
          authorHandle ??= parsedEmbed.authorHandle;
          rawCoverUrl ??= parsedEmbed.coverUrl;
        }
      } catch (_) {}
    }

    authorHandle ??= extractInstagramAuthor(url: url);
    final inlinedCover = await _inlineCoverImage(
      rawCoverUrl,
      referer: 'https://www.instagram.com/',
    );

    final combined = [
      if (bestCaption.isNotEmpty) bestCaption,
      if (extraNotes.isNotEmpty) extraNotes,
    ].where((s) => s.trim().isNotEmpty).join('\n');

    if (combined.isNotEmpty) {
      return SocialPagePayload(
        source: RecipeSource.instagram,
        resolvedUrl: url,
        rawText: combined,
        pageTitle: pageTitle,
        authorHandle: authorHandle,
        coverImageUrl:
            inlinedCover ??
            (rawCoverUrl != null ? _unescapeHtml(rawCoverUrl) : null),
      );
    }

    return null;
  }

  static ({String caption, String? authorHandle, String? coverUrl})
  _parseInstagramEmbedHtml(String html) {
    String caption = '';
    String? author;
    String? cover;

    final userMatch = RegExp(
      r'class="[^"]*(?:UsernameText|CaptionUsername)[^"]*"[^>]*>([^<]+)<',
      caseSensitive: false,
    ).firstMatch(html);
    if (userMatch != null) {
      final u = _unescapeHtml(userMatch.group(1)!).trim().replaceFirst('@', '');
      if (u.isNotEmpty) author = '@$u';
    }

    final imgMatch = RegExp(
      r'<img[^>]+class="[^"]*EmbeddedMediaImage[^"]*"[^>]+src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (imgMatch != null) {
      cover = _unescapeHtml(imgMatch.group(1)!);
    }

    final capMatch = RegExp(
      r'<div[^>]+class="Caption"[^>]*>([\s\S]*?)(?:<div[^>]+class="CaptionComments|</div>)',
      caseSensitive: false,
    ).firstMatch(html);
    if (capMatch != null) {
      String rawCap = capMatch.group(1)!;
      rawCap = rawCap
          .replaceAll(
            RegExp(
              r'<a[^>]+class="[^"]*CaptionUsername[^"]*"[^>]*>[\s\S]*?</a>',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '');
      caption = _unescapeHtml(rawCap).trim();
    }

    return (caption: caption, authorHandle: author, coverUrl: cover);
  }

  static bool _isGenericInstagramLoginPrompt(String text) {
    final l = text.toLowerCase();
    return l.contains('create an account or log in to instagram') ||
        l.contains('створіть обліковий запис або увійдіть') ||
        l == 'instagram';
  }

  static Future<SocialPagePayload> _fetchGenericHtmlOrSocial(
    String url,
    RecipeSource source,
    String extraNotes,
  ) async {
    try {
      final resp = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': _desktopUa,
              'Accept-Language': 'uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final html = utf8.decode(resp.bodyBytes, allowMalformed: true);

        // 1. Check for Schema.org Recipe JSON-LD
        final ldRecipe = _extractSchemaOrgRecipe(html);

        // 2. Extract OpenGraph / Meta tags
        final ogTitle =
            _extractMetaContent(html, 'og:title') ?? _extractHtmlTitle(html);
        final ogDesc =
            _extractMetaContent(html, 'og:description') ??
            _extractMetaContent(html, 'description');
        final ogImage = _extractMetaContent(html, 'og:image');

        final cleanedDesc = source == RecipeSource.instagram
            ? cleanInstagramCaption(ogDesc ?? '')
            : _unescapeHtml(ogDesc ?? '');

        final inlinedImage = source == RecipeSource.instagram
            ? await _inlineCoverImage(
                ogImage,
                referer: 'https://www.instagram.com/',
              )
            : null;

        final combined = [
          if (ogTitle != null && !ogTitle.toLowerCase().contains('instagram'))
            _unescapeHtml(ogTitle),
          if (cleanedDesc.isNotEmpty) cleanedDesc,
          if (extraNotes.isNotEmpty) extraNotes,
        ].where((s) => s.trim().isNotEmpty).join('\n');

        return SocialPagePayload(
          source: source,
          resolvedUrl: url,
          rawText: combined,
          pageTitle: ogTitle != null ? _unescapeHtml(ogTitle) : null,
          coverImageUrl:
              inlinedImage ?? (ogImage != null ? _unescapeHtml(ogImage) : null),
          ldJsonRecipe: ldRecipe,
        );
      }
    } catch (_) {}

    return SocialPagePayload(
      source: source,
      resolvedUrl: url,
      rawText: extraNotes,
    );
  }

  static Map<String, dynamic>? _extractBalancedJsonObject(
    String source,
    String marker,
  ) {
    final markerIdx = source.indexOf(marker);
    if (markerIdx < 0) return null;
    final startIdx = source.indexOf('{', markerIdx + marker.length);
    if (startIdx < 0) return null;

    int depth = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = startIdx; i < source.length; i++) {
      final code = source.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5C /* \ */ ) {
          escaped = true;
        } else if (code == 0x22 /* " */ ) {
          inString = false;
        }
      } else {
        if (code == 0x22 /* " */ ) {
          inString = true;
        } else if (code == 0x7B /* { */ ) {
          depth++;
        } else if (code == 0x7D /* } */ ) {
          depth--;
          if (depth == 0) {
            final jsonSlice = source.substring(startIdx, i + 1);
            try {
              final decoded = jsonDecode(jsonSlice);
              if (decoded is Map<String, dynamic>) return decoded;
            } catch (_) {
              return null;
            }
            return null;
          }
        }
      }
    }
    return null;
  }

  static Map<String, dynamic>? _extractSchemaOrgRecipe(String html) {
    final scripts = RegExp(
      r'<script[^>]+type=["\x27]application/ld\+json["\x27][^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).allMatches(html);

    for (final m in scripts) {
      try {
        final raw = m.group(1)?.trim();
        if (raw == null || raw.isEmpty) continue;
        final parsed = jsonDecode(raw);
        final found = _findRecipeNode(parsed);
        if (found != null) return found;
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic>? _findRecipeNode(dynamic node) {
    if (node is Map<String, dynamic>) {
      final type = node['@type'];
      if (type == 'Recipe' || (type is List && type.contains('Recipe'))) {
        return node;
      }
      if (node['@graph'] is List) {
        for (final item in node['@graph'] as List<dynamic>) {
          final res = _findRecipeNode(item);
          if (res != null) return res;
        }
      }
    } else if (node is List) {
      for (final item in node) {
        final res = _findRecipeNode(item);
        if (res != null) return res;
      }
    }
    return null;
  }

  /// Parses extracted `SocialPagePayload` into a complete, structured `Recipe` matched against `currentPantry`.
  static Recipe parsePayloadToRecipe(
    SocialPagePayload payload,
    List<PantryItem> currentPantry,
  ) {
    final ownedKeys = currentPantry.map((e) => e.canonicalKey).toSet();
    final id = 'imp_${DateTime.now().millisecondsSinceEpoch}';

    // Case A: Structured Schema.org Recipe JSON-LD (Food websites / blogs)
    if (payload.ldJsonRecipe != null) {
      final ld = payload.ldJsonRecipe!;
      final title = _unescapeHtml(
        (ld['name'] as String?) ?? 'Імпортований рецепт',
      );
      final desc = _unescapeHtml(
        (ld['description'] as String?) ?? 'Імпортовано з кулінарного сайту.',
      );
      String? img = payload.coverImageUrl;
      final ldImg = ld['image'];
      if (ldImg is String) img = ldImg;
      if (ldImg is List && ldImg.isNotEmpty && ldImg.first is String) {
        img = ldImg.first as String;
      }
      if (ldImg is Map && ldImg['url'] is String) {
        img = ldImg['url'] as String;
      }

      final rawIngs = (ld['recipeIngredient'] as List<dynamic>?) ?? const [];
      final ingredients = rawIngs
          .map(
            (e) => _parseIngredientLine(
              _unescapeHtml('$e'),
              currentPantry,
              ownedKeys,
            ),
          )
          .whereType<RecipeIngredient>()
          .toList();

      final steps = _parseLdInstructions(ld['recipeInstructions']);
      final cookMins =
          _parseIsoDurationMinutes(
            (ld['totalTime'] as String?) ?? (ld['cookTime'] as String?),
          ) ??
          25;

      if (ingredients.isNotEmpty) {
        return Recipe(
          id: id,
          title: title,
          description: desc,
          cookMinutes: cookMins,
          difficulty: cookMins <= 20 ? 'Легко' : 'Середньо',
          defaultServings: 2,
          caloriesPerServing: 390,
          rescuedGrams: 200,
          imageUrl: img,
          imageAsset: 'assets/images/img_01.jpg',
          source: payload.source,
          sourceUrl: payload.resolvedUrl,
          authorHandle: payload.authorHandle,
          tags: const ['imported'],
          sousChefAdvice: _buildSousChefTip(ingredients, ownedKeys),
          ingredients: ingredients,
          steps: steps.isNotEmpty
              ? steps
              : _buildFallbackStepsFromIngredients(title, ingredients),
        );
      }
    }

    // Case B: Social Media Caption / Subtitles / Pasted Recipe Text (TikTok, Instagram Reels, YouTube Shorts, User Text)
    final raw = _normalizeFractions(payload.combinedText.trim());
    if (raw.isEmpty) {
      throw const RecipeImportException(
        'Не вдалося прочитати опис за цим посиланням. Додайте список інгредієнтів або текст рецепта прямо у поле нижче.',
      );
    }

    final hashtags = RegExp(
      r'#([^\s#.,!?;:]+)',
    ).allMatches(raw).map((m) => m.group(1)!).toList();

    final withoutTags = raw
        .replaceAll(RegExp(r'#[^\s#]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Split by newlines and explicit bullets (preserving mid-line " - " separators like "сир - 350 г")
    final rawNoTags = raw.replaceAll(RegExp(r'#[^\s#]+'), '');
    final hasNewlines = rawNoTags.contains('\n');
    final bulletSplitRegex = hasNewlines
        ? RegExp(
            r'(?:\r?\n+|(?:^|\s+)(?:[•▪▫▫️▪️✅✔️✔☑️🔸🔹👉👉🏼✦📌📍➤]|[🍓🥄🥚🧀🥛🍯🍋🍅🥬🧄🧅🥑🍌🍎🌾🧈🍗🥩🍝🥣])\s*)',
          )
        : RegExp(
            r'(?:\r?\n+|(?:\s+|^)[-–—]\s+(?!\d)|(?:\s+|^)(?:[•▪▫▫️▪️✅✔️✔☑️🔸🔹👉👉🏼✦📌📍➤*]|[🍓🥄🥚🧀🥛🍯🍋🍅🥬🧄🧅🥑🍌🍎🌾🧈🍗🥩🍝🥣])\s*)',
          );
    final coarseChunks = rawNoTags
        .split(bulletSplitRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Further split TikTok/Shorts collapsed lines where an ingredient quantity+unit is immediately followed by a Capitalized sentence
    final segments = <String>[];
    final collapsedSplit = RegExp(
      r'^(.+?(?:\d+\s*(?:[-–]\s*\d+)?\s*(?:г|гр|кг|мл|л|шт\.?|ст\.?\s*л\.?|ч\.?\s*л\.?|склянк[а-яіїєґ]*|зубч[а-яіїєґ]*|пуч[а-яіїєґ]*|пачк[а-яіїєґ]*|tbsp|tsp|cups?|oz|g|kg|ml))\.?)\s+([А-ЯІЇЄҐA-Z][а-яіїєґa-z]{2,}\s+.+)$',
    );
    for (final chunk in coarseChunks) {
      final m = collapsedSplit.firstMatch(chunk);
      if (m != null) {
        segments.add(m.group(1)!.trim());
        segments.addAll(_splitCollapsedSentences(m.group(2)!.trim()));
      } else {
        segments.addAll(_splitCollapsedSentences(chunk));
      }
    }

    String? detectedTitle;
    if (payload.pageTitle != null &&
        payload.pageTitle!.trim().isNotEmpty &&
        payload.source == RecipeSource.youtube) {
      final ytTitle = _cleanSocialVideoTitle(payload.pageTitle!);
      if (ytTitle.length >= 3) {
        detectedTitle = _normalizeTitleCase(ytTitle);
      }
    }

    final proseLines = <String>[];
    final ingredients = <RecipeIngredient>[];
    bool inIngredientsSection = false;
    bool sawIngredientsHeader = false;
    bool inStepsSection = false;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i].trim();
      if (seg.isEmpty) continue;

      if (_isIngredientsHeader(seg)) {
        inIngredientsSection = true;
        sawIngredientsHeader = true;
        inStepsSection = false;
        continue;
      }
      if (_isStepsHeader(seg)) {
        inIngredientsSection = false;
        inStepsSection = true;
        continue;
      }
      if (_isSocialBoilerplateLine(seg)) {
        continue;
      }

      // Keycap numbered steps like "1️⃣ Mix..." or "2️⃣ Bake..." belong to cooking steps
      final isNumberedStep = _isExplicitNumberedStep(seg);
      if (isNumberedStep) {
        inIngredientsSection = false;
        inStepsSection = true;
      }

      if (!isNumberedStep &&
          !inStepsSection &&
          _looksLikeIngredient(seg, inSection: inIngredientsSection)) {
        final parsed = _parseIngredientLine(seg, currentPantry, ownedKeys);
        if (parsed != null) {
          _addUniqueIngredient(ingredients, parsed);
          continue;
        }
      }

      final strippedStep = _stripStepNumberPrefix(seg);
      if (detectedTitle == null &&
          i == 0 &&
          !isNumberedStep &&
          !_looksLikeCookingAction(strippedStep)) {
        final cleanCandidate = _cleanSocialVideoTitle(strippedStep);
        final commaIdx = cleanCandidate.indexOf(',');
        if (commaIdx > 3 && commaIdx <= 48) {
          detectedTitle = _normalizeTitleCase(
            cleanCandidate.substring(0, commaIdx).trim(),
          );
          proseLines.add(_capitalize(strippedStep));
        } else if (cleanCandidate.length <= 68) {
          detectedTitle = _normalizeTitleCase(
            cleanCandidate.replaceAll(RegExp(r'[.!?:]+$'), ''),
          );
        } else {
          final words = cleanCandidate.split(' ');
          detectedTitle = _normalizeTitleCase(words.take(5).join(' '));
          proseLines.add(strippedStep);
        }
      } else if (strippedStep.isNotEmpty) {
        proseLines.add(strippedStep);
      }
    }

    // Fallback title from hashtags or payload pageTitle if caption started directly with ingredients
    if (detectedTitle == null || detectedTitle.length < 3) {
      final dishTag = hashtags.firstWhere(
        (t) => ![
          'рецепт',
          'рецепти',
          'рецептиукраїнською',
          'їжа',
          'смачно',
          'рек',
          'fyp',
          'recipe',
          'recipes',
          'shorts',
          'shortvideo',
          'reels',
          'food',
        ].contains(t.toLowerCase()),
        orElse: () =>
            payload.pageTitle ?? 'Домашня страва з ${payload.source.label}',
      );
      detectedTitle = _humanizeHashtag(dishTag);
    }

    final pass1ExplicitCount = ingredients.length;
    final authorHadExplicitList = _hasEnoughExplicitIngredients(payload.rawText);

    // Pass 2: Extract inline / spoken ingredients from continuous subtitle transcripts or prose sentences
    if (!sawIngredientsHeader &&
        (ingredients.length < 4 ||
            proseLines.length > 5 ||
            payload.transcript.trim().isNotEmpty)) {
      final transcriptIngs = _extractSpokenOrInlineIngredients(
        withoutTags,
        currentPantry,
        ownedKeys,
      );
      for (final ing in transcriptIngs) {
        _addUniqueIngredient(ingredients, ing);
      }
    }

    // Pass 3: Supplement from spoken transcript / prose vocabulary!
    // Whenever there was NO explicit structured list (e.g. spoken transcript without bullet list),
    // automatically pick up EVERY food ingredient mentioned in the speech/prose even without numbers!
    if (!sawIngredientsHeader &&
        (pass1ExplicitCount < 3 || payload.transcript.trim().isNotEmpty)) {
      final sourceForProse = payload.transcript.trim().isNotEmpty &&
              !authorHadExplicitList
          ? '${payload.rawText}\n${payload.transcript}\n${payload.onScreenText}'
          : withoutTags;
      for (final ing in _extractImplicitIngredientsFromProse(
        sourceForProse,
        currentPantry,
        ownedKeys,
      )) {
        _addUniqueIngredient(ingredients, ing);
      }
    }

    // Pass 4: Culinary Dish Knowledge Graph — if video had NO explicit description list
    // (or only music + dish title/hashtag like "Деруни", "Карбонара", "Ліниві вареники"),
    // automatically infer & complete missing essential ingredients of that dish!
    bool usedDishInference = false;
    if (!authorHadExplicitList && pass1ExplicitCount < 2) {
      final dishContext = [
        detectedTitle,
        ...hashtags,
        if (payload.pageTitle != null) payload.pageTitle!,
      ].join(' ');
      final inferred = _inferCanonicalDishIngredients(
        dishContext,
        currentPantry,
        ownedKeys,
      );
      for (final ing in inferred) {
        final beforeLen = ingredients.length;
        _addUniqueIngredient(ingredients, ing);
        if (ingredients.length > beforeLen) {
          usedDishInference = true;
        }
      }
    }

    if (ingredients.isEmpty) {
      final triedSources = [
        'опис',
        if (payload.transcript.isNotEmpty) 'субтитри',
        if (payload.onScreenText.isNotEmpty) 'текст у відео',
      ].join(', ');
      throw RecipeImportException(
        'У публікації «$detectedTitle» не знайшлося інгредієнтів (перевірено: $triedSources). '
        '${payload.videoUrl != null && payload.onScreenText.isEmpty ? 'Додайте Gemini API ключ у профілі, щоб розпізнавати текст прямо з відео, або допишіть' : 'Допишіть'} 2–3 основні продукти через кому у поле вище!',
      );
    }

    final steps = _buildStepsFromProse(proseLines, detectedTitle, ingredients);

    // Estimate total cook time from step timers or explicit mentions
    int totalMinutes = 0;
    for (final s in steps) {
      totalMinutes += (s.timerSeconds / 60).ceil();
    }
    if (totalMinutes < 8) {
      final normTimeText = _normalizeSpokenNumbers(withoutTags);
      final timeMatch = RegExp(
        r'(\d+)\s*(?:хв|min)',
        caseSensitive: false,
      ).firstMatch(normTimeText);
      final mentioned = timeMatch != null
          ? int.tryParse(timeMatch.group(1)!) ?? 0
          : 0;
      totalMinutes = (mentioned > 0 ? mentioned + 10 : 15).clamp(10, 90);
    }

    final authorPrefix = payload.authorHandle != null
        ? 'Рецепт від ${payload.authorHandle} (${payload.source.label}): '
        : 'Імпортовано з ${payload.source.label}: ';

    final summaryDesc = proseLines.isNotEmpty
        ? '$authorPrefix${proseLines.first}'
        : '$authorPrefix${ingredients.map((e) => e.name.toLowerCase()).take(4).join(', ')}.';

    String chefTip = _buildSousChefTip(ingredients, ownedKeys);
    if (!authorHadExplicitList && payload.transcript.trim().isNotEmpty) {
      chefTip =
          '🎙️ В описі відео не було списку продуктів — Crisper автоматично розпізнав і виписав інгредієнти прямо з розшифровки мовлення відео! $chefTip';
    } else if (usedDishInference) {
      chefTip =
          '🧠 Автор не вказав повний рецепт в описі — Crisper сам відновив базові інгредієнти страви «$detectedTitle»! $chefTip';
    }

    return Recipe(
      id: id,
      title: detectedTitle,
      description: summaryDesc,
      cookMinutes: totalMinutes,
      difficulty: totalMinutes <= 20 ? 'Легко' : 'Середньо',
      defaultServings: 2,
      caloriesPerServing: 360,
      rescuedGrams: 220,
      imageUrl: payload.coverImageUrl,
      imageAsset: 'assets/images/img_03.jpg',
      source: payload.source,
      sourceUrl: payload.resolvedUrl.isEmpty ? null : payload.resolvedUrl,
      authorHandle: payload.authorHandle,
      tags: ['imported', if (totalMinutes <= 25) 'quick'],
      sousChefAdvice: chefTip,
      ingredients: ingredients,
      steps: steps,
    );
  }

  static void _addUniqueIngredient(
    List<RecipeIngredient> list,
    RecipeIngredient candidate,
  ) {
    final lowerName = candidate.name.toLowerCase();
    final exists = list.any(
      (e) =>
          e.name.toLowerCase() == lowerName ||
          (e.canonicalKey == candidate.canonicalKey &&
              candidate.canonicalKey != 'ingredient' &&
              e.unit == candidate.unit),
    );
    if (!exists) {
      list.add(candidate);
    }
  }

  /// True when the text already carries a usable ingredient list: either ≥2 explicit
  /// ingredient lines, or ≥3 distinct foods mentioned (e.g. in spoken subtitles).
  static bool hasIngredientSignal(String text) {
    if (text.trim().isEmpty) return false;
    if (_hasEnoughExplicitIngredients(text)) return true;
    return _extractImplicitIngredientsFromProse(
          text.replaceAll(RegExp(r'#[^\s#]+'), ' '),
          const [],
          const {},
        ).length >=
        3;
  }

  static bool _hasEnoughExplicitIngredients(String text) {
    if (text.trim().isEmpty) return false;
    final normalized = _normalizeFractions(text);
    final lines = normalized.split(RegExp(r'\r?\n+'));
    int count = 0;
    bool inSec = false;
    for (final rawLine in lines) {
      final l = rawLine.trim();
      if (l.isEmpty) continue;
      if (_isIngredientsHeader(l)) {
        inSec = true;
        continue;
      }
      if (_isStepsHeader(l)) {
        inSec = false;
        continue;
      }
      if (_looksLikeIngredient(l, inSection: inSec)) {
        count++;
        if (count >= 2) return true;
      }
    }
    return false;
  }

  static String _normalizeFractions(String input) {
    return input
        .replaceAll('½', '0.5')
        .replaceAll('⅓', '0.33')
        .replaceAll('⅔', '0.67')
        .replaceAll('¼', '0.25')
        .replaceAll('¾', '0.75')
        .replaceAllMapped(RegExp(r'(\d+)\s+(\d+)/(\d+)'), (m) {
          final whole = double.tryParse(m.group(1)!) ?? 0;
          final num = double.tryParse(m.group(2)!) ?? 0;
          final den = double.tryParse(m.group(3)!) ?? 1;
          return den > 0 ? (whole + num / den).toStringAsFixed(2) : m.group(0)!;
        })
        .replaceAllMapped(RegExp(r'(?<!\d)(\d+)/(\d+)(?!\d)'), (m) {
          final num = double.tryParse(m.group(1)!) ?? 0;
          final den = double.tryParse(m.group(2)!) ?? 1;
          if (den == 2 || den == 3 || den == 4 || den == 8) {
            return (num / den)
                .toStringAsFixed(2)
                .replaceFirst(RegExp(r'0+$'), '')
                .replaceFirst(RegExp(r'\.$'), '');
          }
          return m.group(0)!;
        });
  }

  static bool _isIngredientsHeader(String line) {
    final l = line
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zа-яіїєґ\s]'), '')
        .trim();
    return const {
      'інгредієнти',
      'інгрідієнти',
      'ингредиенты',
      'ингридиенты',
      'складові',
      'продукти',
      'ingredients',
      'what you need',
      'you will need',
    }.contains(l);
  }

  static bool _isStepsHeader(String line) {
    final l = line
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zа-яіїєґ\s]'), '')
        .trim();
    return const {
      'приготування',
      'спосіб приготування',
      'етапи приготування',
      'процес приготування',
      'процес',
      'приготовление',
      'instructions',
      'directions',
      'method',
      'steps',
      'preparation',
      'how to make',
    }.contains(l);
  }

  static bool _isSocialBoilerplateLine(String line) {
    final l = line.toLowerCase().trim();
    if (l.isEmpty) return true;
    final wordsOnly = l.replaceAll(RegExp(r'[^a-zа-яіїєґ\s]'), '').trim();
    if (const {
      'смачного',
      'приємного апетиту',
      'приятного аппетита',
      'enjoy',
      'bon appetit',
    }.contains(wordsOnly)) {
      return true;
    }
    if (l.contains('підписатися') ||
        l.contains('підписуйтесь') ||
        l.contains('поставте реакцію') ||
        l.contains('шапке профиля') ||
        l.contains('follow for more') ||
        l.contains('comment recipe')) {
      return true;
    }
    return false;
  }

  static bool _isExplicitNumberedStep(String line) {
    if (RegExp(r'^\s*(?:10|[1-9])\uFE0F?\u20E3').hasMatch(line)) return true;
    if (RegExp(
      r'^\s*(?:крок|step)\s*\d+[:.)\s]',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }
    final numbered = RegExp(r'^\s*\d+[.)]\s+(.+)$').firstMatch(line);
    if (numbered != null && _looksLikeCookingAction(numbered.group(1)!)) {
      return true;
    }
    return false;
  }

  static String _stripStepNumberPrefix(String line) {
    return line
        .replaceFirst(RegExp(r'^\s*(?:10|[1-9])\uFE0F?\u20E3\s*'), '')
        .replaceFirst(
          RegExp(r'^\s*(?:крок|step)\s*\d+[:.)\s]*', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'^\s*\d+[.)]\s+'), '')
        .trim();
  }

  static List<String> _splitCollapsedSentences(String text) {
    return text
        .split(
          RegExp(
            r'(?<=[.!?])\s+(?=[А-ЯІЇЄҐA-Z0-9])|(?<=[а-яіїєґa-z0-9.])\s+(?=(?:Також|Варю|Варимо|Варити|Коли|Потім|Далі|Додаємо|Додайте|Змішуємо|Змішайте|Формуємо|Смажимо|Обсмажте|Випікаємо|Запікайте|Подаємо|Готуємо|Нарізаємо)(?![а-яіїєґa-z])|(?:Mix|Blend|Whisk|Combine|Bake|Cook|Fry|Pour|Serve|Preheat|Add)(?=\s+[a-z]))',
          ),
        )
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static bool _looksLikeIngredient(String line, {bool inSection = false}) {
    final withoutParens = line
        .replaceAll(
          RegExp(
            r'^[-–—•▪▫▫️▪️✅✔️✔☑️🔸🔹👉👉🏼✦📌📍➤*\s🍓🥄🥚🧀🥛🍯🍋🍅🥬🧄🧅🥑🍌🍎🌾🧈🍗🥩🍝🥣]+',
          ),
          '',
        )
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\+\s*.*$'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    final l = withoutParens.toLowerCase();
    final fullLower = line.trim().toLowerCase();
    if (l.isEmpty || l.length > 90) return false;
    if (_isExplicitNumberedStep(line)) return false;
    if (_looksLikeCookingAction(l) && !inSection) return false;

    // 1. Numeric quantity + culinary unit (Ukrainian or English, in main text or inside parenthetical note)
    final qtyUnitPattern = RegExp(
      r'(\d+(?:[.,/-]\d+)?)\s*(г|гр|грам[а-яіїєґ]*|кг|мл|л|шт\.?|штук[а-яіїєґ]*|ст\.?\s*л\.?|ст\.?\s*лож[а-яіїєґ]*|столов[а-яіїєґ]+\s+лож[а-яіїєґ]+|ч\.?\s*л\.?|ч\.?\s*лож[а-яіїєґ]*|чайн[а-яіїєґ]+\s+лож[а-яіїєґ]+|склянк[а-яіїєґ]*|зубч[а-яіїєґ]*|пуч[а-яіїєґ]*|пачк[а-яіїєґ]*|брикет[а-яіїєґ]*|уп\.?|дрібк[а-яіїєґ]*|щіпк[а-яіїєґ]*|g|gr|grams?|kg|ml|l|oz|lbs?|tbsp|tbs|tablespoons?|tsp|teaspoons?|cups?|pcs?|pieces?|cloves?|pinch(?:es)?|slices?|scoops?|handfuls?|cans?)(?![а-яіїєґa-z])',
      caseSensitive: false,
    );
    if ((qtyUnitPattern.hasMatch(l) || qtyUnitPattern.hasMatch(fullLower)) &&
        l.split(' ').length <= 9 &&
        !_looksLikeCookingAction(l)) {
      return true;
    }

    // 2. Unitless counted whole ingredients ("1 яйце", "2 eggs", "1 жовток", "2 bananas", "1 avocado", "1 цибулина")
    final unitlessCountPattern = RegExp(
      r'^[-–—•*\s]*(\d+(?:[.,]\d+)?)\s+(яйц[ея]|яєць|жовт[а-яіїєґ]+|білк[а-яіїєґ]+|цибулин[а-яіїєґ]*|банан[а-яіїєґ]*|авокадо|лимон[а-яіїєґ]*|яблук[а-яіїєґ]*|огір[а-яіїєґ]+|помідор[а-яіїєґ]*|томат[а-яіїєґ]*|моркв[а-яіїєґ]*|картоплин[а-яіїєґ]*|зубчик[а-яіїєґ]*|eggs?|egg\s+yolks?|egg\s+whites?|bananas?|avocados?|lemons?|limes?|onions?|apples?|tomatoes|cucumbers?|carrots?|potatoes)(?![а-яіїєґa-z])',
      caseSensitive: false,
    );
    if (unitlessCountPattern.hasMatch(l) && l.split(' ').length <= 8) {
      return true;
    }

    // 3. Pinch / to-taste / spice / dusting items ("дрібка солі", "щіпка ваніліну або ванільного цукру", "salt to taste")
    if (l.split(' ').length <= 7 &&
        !_looksLikeCookingAction(l) &&
        (l.contains('дрібка') ||
            l.contains('щіпка') ||
            l.contains('щепотка') ||
            l.contains('за смаком') ||
            l.contains('по вкусу') ||
            l.contains('to taste') ||
            l.contains('pinch of') ||
            l.contains('ванільн') ||
            l.contains('ванілін') ||
            l.contains('vanilla') ||
            l.contains('розпушувач') ||
            l.contains('baking powder'))) {
      return true;
    }

    // 4. Short food item inside explicit "Інгредієнти:" / "Ingredients:" section (e.g. "борошно для панірування", "олія для смаження")
    if (inSection && l.split(' ').length <= 5 && !_looksLikeCookingAction(l)) {
      final canonical = IngredientNormalizer.canonicalize(l);
      if (!canonical.contains('_') ||
          const {
            'cottage_cheese',
            'cream_cheese',
            'hard_cheese',
            'greek_yogurt',
            'sour_cream',
            'heavy_cream',
            'vanilla_sugar',
            'powdered_sugar',
            'baking_powder',
            'cherry_tomatoes',
            'bell_pepper',
            'chicken_fillet',
            'olive_oil',
          }.contains(canonical)) {
        return true;
      }
    }

    return false;
  }

  static bool _looksLikeCookingAction(String line) {
    final l = line.trim().toLowerCase();
    return RegExp(
      r'(?<![а-яіїєґa-z])(варит|варю|варимо|смаж|підсмаж|обсмаж|запіка|випіка|зміша|змішу|переміш|вимина|збий|додай|додаєм|наріж|наріза|обваля|обвалю|сформу|формує|залиш|подава|накрива|переверта|кипін|закипан|хвилин|духовк|пательн|сковород|блендер)|(?<![a-z])(mix|blend|whisk|stir|combine|boil|simmer|preheat|pour|chop|slice|dice|serve|minutes|mins|oven|skillet)(?![a-z])|(?<![a-z])(bake|fry|cook)(?=\s+[a-z0-9])',
    ).hasMatch(l);
  }

  static RecipeIngredient? _parseIngredientLine(
    String rawLine,
    List<PantryItem> currentPantry,
    Set<String> ownedKeys,
  ) {
    final clean = rawLine
        .replaceAll(
          RegExp(
            r'^[-–—•▪▫▫️▪️✅✔️✔☑️🔸🔹👉👉🏼✦📌📍➤*\s🍓🥄🥚🧀🥛🍯🍋🍅🥬🧄🧅🥑🍌🍎🌾🧈🍗🥩🍝🥣]+',
          ),
          '',
        )
        .replaceAll(RegExp(r'[.;,]+$'), '')
        .trim();
    if (clean.isEmpty) return null;

    double amount = 1;
    String unit = 'шт';
    String namePart = clean;

    final qtyRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)(?:\s*[-–]\s*(\d+(?:[.,]\d+)?))?\s*(ст\.?\s*л\.?|ст\.?\s*лож[а-яіїєґ]*|столов[а-яіїєґ]+\s+лож[а-яіїєґ]+|ч\.?\s*л\.?|ч\.?\s*лож[а-яіїєґ]*|чайн[а-яіїєґ]+\s+лож[а-яіїєґ]+|склянк[а-яіїєґ]*|зубч[а-яіїєґ]*|пуч[а-яіїєґ]*|пачк[а-яіїєґ]*|брикет[а-яіїєґ]*|дрібк[а-яіїєґ]*|щіпк[а-яіїєґ]*|кг|гр|г|грам[а-яіїєґ]*|мл|л|шт\.?|штук[а-яіїєґ]*|уп\.?|tablespoons?|tbsp|tbs|teaspoons?|tsp|cups?|cloves?|pinch(?:es)?|slices?|scoops?|handfuls?|cans?|grams?|kg|ml|oz|lbs?|g|pcs?|pieces?)\.?(?![а-яіїєґa-z])',
      caseSensitive: false,
    );

    final withoutParens = clean.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final mMain = qtyRegex.firstMatch(withoutParens);
    final mFull = mMain ?? qtyRegex.firstMatch(clean);

    if (mFull != null) {
      final n1 = double.tryParse(mFull.group(1)!.replaceAll(',', '.')) ?? 1;
      final n2 = mFull.group(2) != null
          ? double.tryParse(mFull.group(2)!.replaceAll(',', '.'))
          : null;
      amount = n2 ?? n1;
      unit = _normalizeUnit(mFull.group(3)!);
      if (mMain != null) {
        namePart = withoutParens
            .replaceRange(mMain.start, mMain.end, ' ')
            .trim();
      } else {
        namePart = withoutParens.trim();
      }
    } else {
      // Check unitless leading count ("1 яйце", "2 eggs", "1 жовток")
      final countMatch = RegExp(
        r'^(\d+(?:[.,]\d+)?)\s+(.+)$',
      ).firstMatch(withoutParens.trim());
      if (countMatch != null) {
        amount =
            double.tryParse(countMatch.group(1)!.replaceAll(',', '.')) ?? 1;
        unit = 'шт';
        namePart = countMatch.group(2)!.trim();
      } else if (RegExp(
        r'(дрібка|щіпка|щепотка|pinch\s+of|pinch)',
        caseSensitive: false,
      ).hasMatch(clean)) {
        amount = 1;
        unit = 'дрібка';
        namePart = withoutParens
            .replaceAll(
              RegExp(
                r'(дрібка|щіпка|щепотка|a\s+pinch\s+of|pinch\s+of|pinch)\s*',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
      } else if (clean.toLowerCase().contains('ванільн') ||
          clean.toLowerCase().contains('ванілін') ||
          clean.toLowerCase().contains('vanilla')) {
        amount = 1;
        unit = 'ч. л.';
        namePart = withoutParens.trim();
      } else {
        namePart = withoutParens.trim();
      }
    }

    // Clean qualifiers ("за смаком", "без гірки", "з гіркою", "+ борошно...", "of ")
    namePart = namePart
        .replaceAll(RegExp(r'\+\s*.*$'), '')
        .replaceAll(
          RegExp(
            r'(?<![а-яіїєґa-zА-ЯІЇЄҐA-Z])(за смаком|по вкусу|to taste|без гірки|з гіркою|для смаження|для жарки|для панірування|для обвалки|for frying|for dusting)(?![а-яіїєґa-zА-ЯІЇЄҐA-Z])',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+[-–—:]\s*$'), '')
        .replaceAll(RegExp(r'^[-–—:]+\s*|\s*[-–—:,]+$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (namePart.isEmpty) {
      namePart = withoutParens.trim();
    }
    if (namePart.isEmpty) return null;

    final displayName = _beautifyIngredientName(namePart);
    final canonical = _canonicalizeWithEnglishSupport(
      displayName,
      currentPantry,
    );
    final sub = IngredientNormalizer.suggestSubstitution(canonical, ownedKeys);

    return RecipeIngredient(
      name: displayName,
      canonicalKey: canonical,
      baseAmount: amount,
      unit: unit,
      prepNote: ownedKeys.contains(canonical)
          ? 'Є у вашому холодильнику'
          : 'За рецептом автора',
      substituteKey: sub.$1,
      substituteTip: sub.$2,
    );
  }

  static String _normalizeSpokenNumbers(String input) {
    return input
        .toLowerCase()
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(пів\s*кіло|півкіло|полкило)(?![а-яіїєґa-z])'),
          (_) => '500 г',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(пів\s*години|півгодини|полчаса|half\s+an?\s+hour)(?![а-яіїєґa-z])'),
          (_) => '30 хв',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(пачк[ау]\s+(?:кисломолочного\s+)?сиру|пачк[ау]\s+творог[ау])(?![а-яіїєґa-z])'),
          (_) => '250 г сиру кисломолочного',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(пачк[ау]\s+(?:вершкового\s+)?масла)(?![а-яіїєґa-z])'),
          (_) => '180 г вершкового масла',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(баночк[ау]\s+йогурт[ау])(?![а-яіїєґa-z])'),
          (_) => '180 г грецького йогурту',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(баночк[ау]\s+сметан[иу])(?![а-яіїєґa-z])'),
          (_) => '200 г сметани',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(п\x27ятсот|пятсот|five\s+hundred)(?![а-яіїєґa-z])'),
          (_) => '500',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(чотириста|четыреста|four\s+hundred)(?![а-яіїєґa-z])'),
          (_) => '400',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(триста|three\s+hundred)(?![а-яіїєґa-z])'),
          (_) => '300',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(двісті|двести|two\s+hundred)(?![а-яіїєґa-z])'),
          (_) => '200',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(сто\s+п\x27ятдесят|сто\s+пятдесят)(?![а-яіїєґa-z])'),
          (_) => '150',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(сто|one\s+hundred)(?=\s+(?:г|гр|грам|мл|g|grams|ml))'),
          (_) => '100',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(п\x27ятдесят|пятдесят|fifty)(?=\s+(?:г|гр|грам|мл|g|grams|ml))'),
          (_) => '50',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(двадцять|двадцать|twenty)(?=\s+(?:хв|сек|г|гр|мл|min))'),
          (_) => '20',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(п\x27ятнадцять|пятнадцять|пятнадцать|fifteen)(?=\s+(?:хв|сек|г|гр|мл|min))'),
          (_) => '15',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(десять|десят|ten)(?=\s+(?:хв|сек|г|гр|мл|шт|min))'),
          (_) => '10',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(шість|шесть|six)(?=\s+(?:хв|яйц|яєць|ст|столов|ч\.|чайн|зубч|лож|min|eggs?|tbsp|tsp))'),
          (_) => '6',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(п\x27ять|пять|five)(?=\s+(?:хв|яйц|яєць|ст|столов|ч\.|чайн|зубч|лож|min|eggs?|tbsp|tsp))'),
          (_) => '5',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(півтор[аи]|полтор[аы])(?=\s+(?:склян|стакан|лож|ст|ч\.))'),
          (_) => '1.5',
        )
        .replaceAllMapped(
          RegExp(r'(?<![а-яіїєґa-z])(пів|пол|половину|half\s+a)(?=\s+(?:склян|стакан|лимон|цибул|авокадо|банан|пачк|cup|lemon|onion|avocado))'),
          (_) => '0.5',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(один|одна|одне|одну|one)(?=\s+(?:яйц|жовт|біл|ст|столов|ч\.|чайн|склян|зубч|пуч|дрібк|щіпк|банан|авокадо|лимон|цибул|яблук|моркв|огір|помідор|томат|хв|egg|tbsp|tablespoon|tsp|teaspoon|cup|pinch|clove|banana|avocado|lemon|onion|min))',
          ),
          (_) => '1',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(два|дві|здві|пару|two)(?=\s+(?:яйц|жовт|біл|ст|столов|ч\.|чайн|склян|зубч|пуч|банан|авокадо|лимон|цибул|огір|помідор|томат|хв|лож|egg|tbsp|tablespoon|tsp|teaspoon|cup|clove|banana|avocado|lemon|onion|min))',
          ),
          (_) => '2',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(три|three)(?=\s+(?:яйц|жовт|біл|ст|столов|ч\.|чайн|склян|зубч|хв|лож|egg|tbsp|tablespoon|tsp|teaspoon|cup|clove|min))',
          ),
          (_) => '3',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(чотири|четыре|four)(?=\s+(?:яйц|ст|столов|ч\.|чайн|склян|зубч|хв|лож|egg|tbsp|tablespoon|tsp|teaspoon|cup|clove|min))',
          ),
          (_) => '4',
        );
  }

  /// Extracts spoken or inline ingredients from continuous subtitle transcripts (YouTube auto-captions / spoken Reels / TikTok ASR).
  static List<RecipeIngredient> _extractSpokenOrInlineIngredients(
    String prose,
    List<PantryItem> currentPantry,
    Set<String> ownedKeys,
  ) {
    final results = <RecipeIngredient>[];
    if (prose.trim().isEmpty) return results;

    // Normalize common Ukrainian and English spoken number words into digits for parsing
    final normalized = _normalizeSpokenNumbers(prose)
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])((?:така\s+)?(?:повн[ау]\s+)?чайн[ау]\s+ложк[ау]|a\s+teaspoon(?:\s+of)?)(?=\s+[а-яіїєґa-z])',
          ),
          (_) => '1 чл',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])((?:така\s+)?(?:повн[ау]\s+)?столов[ау]\s+ложк[ау]|a\s+tablespoon(?:\s+of)?|ложк[ау])(?=\s+(?:борошн|цукр|сметан|олі|масл|крохмал|манк|какао|меду))',
          ),
          (_) => '1 стл',
        )
        .replaceAllMapped(
          RegExp(
            r'(?<![а-яіїєґa-z])(дрібк[ау]|щіпк[ау]|a\s+pinch\s+of)(?=\s+[а-яіїєґa-z])',
          ),
          (_) => '1 дрібка',
        );

    // Split prose into clauses by punctuation and conjunctions ("with", "and", "та", "і")
    final clauses = normalized
        .split(
          RegExp(
            r'[.!?;,\n]+|\s+(?:with|and|plus|та|і|й|а також)\s+',
            caseSensitive: false,
          ),
        )
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    final inlineCapture = RegExp(
      r'(\d+(?:[.,]\d+)?\s*(?:г|гр|кг|мл|л|шт\.?|ст\.?\s*л\.?|ч\.?\s*л\.?|дрібка|склянк[а-яіїєґ]*|зубч[а-яіїєґ]*|tbsp|tablespoons?|tsp|teaspoons?|cups?|oz|g|kg|ml|pinch|cloves?)?\s*(?:of\s+)?[а-яіїєґa-zА-ЯІЇЄҐA-Z][а-яіїєґa-zА-ЯІЇЄҐA-Z\s%-]{1,34})',
    );

    for (final clause in clauses) {
      if (_looksLikeIngredient(clause)) {
        final parsed = _parseIngredientLine(clause, currentPantry, ownedKeys);
        if (parsed != null && _isKnownFoodCanonical(parsed.canonicalKey)) {
          _addUniqueIngredient(results, parsed);
          continue;
        }
      }

      for (final m in inlineCapture.allMatches(clause)) {
        final snippet = m.group(1)!.trim();
        if (_looksLikeCookingAction(snippet)) continue;
        // Trim trailing non-food words if any
        final words = snippet.split(RegExp(r'\s+'));
        for (int len = words.length.clamp(1, 5); len >= 2; len--) {
          final subSnippet = words.take(len).join(' ');
          if (_looksLikeIngredient(subSnippet)) {
            final parsed = _parseIngredientLine(
              subSnippet,
              currentPantry,
              ownedKeys,
            );
            if (parsed != null && _isKnownFoodCanonical(parsed.canonicalKey)) {
              _addUniqueIngredient(results, parsed);
              break;
            }
          }
        }
      }
    }

    return results;
  }

  static bool _isKnownFoodCanonical(String key) {
    const known = {
      'cottage_cheese',
      'parmesan',
      'cheddar',
      'mozzarella',
      'feta',
      'cream_cheese',
      'hard_cheese',
      'processed_cheese',
      'greek_yogurt',
      'sour_cream',
      'kefir',
      'butter',
      'heavy_cream',
      'milk',
      'eggs',
      'vanilla_sugar',
      'powdered_sugar',
      'sugar',
      'honey',
      'flour',
      'starch',
      'baking_powder',
      'semolina',
      'oats',
      'buckwheat',
      'rice',
      'pasta',
      'bread',
      'spinach',
      'cherry_tomatoes',
      'cucumber',
      'bell_pepper',
      'zucchini',
      'eggplant',
      'broccoli',
      'cabbage',
      'potato',
      'carrot',
      'beetroot',
      'onion',
      'garlic',
      'basil',
      'herbs',
      'mushrooms',
      'avocado',
      'lemons',
      'banana',
      'apple',
      'berries',
      'chicken_fillet',
      'turkey',
      'beef',
      'pork',
      'salmon',
      'shrimp',
      'olive_oil',
      'chocolate',
      'salt',
    };
    return known.contains(key);
  }

  static String _canonicalizeWithEnglishSupport(
    String name,
    List<PantryItem> pantry,
  ) {
    final l = name.toLowerCase();
    if (l.contains('strawberr') ||
        l.contains('blueberr') ||
        l.contains('raspberr') ||
        l.contains('berr') ||
        l.contains('cherries')) {
      return 'berries';
    }
    if (l.contains('shrimp') || l.contains('prawn')) return 'shrimp';
    if (l.contains('herb') ||
        l.contains('parsley') ||
        l.contains('dill') ||
        l.contains('cilantro')) {
      return 'herbs';
    }
    return IngredientNormalizer.canonicalize(name, pantry);
  }

  static String _beautifyIngredientName(String raw) {
    final l = raw.toLowerCase().trim();
    if (l == 'сир' ||
        l == 'сиру' ||
        l == 'кисломолочного сиру' ||
        l == 'сиру кисломолочного' ||
        l == 'творога' ||
        l == 'творог') {
      return 'Сир кисломолочний';
    }
    if (l == 'яйце' || l == 'яйця') return 'Яйце куряче';
    if (l == 'жовток' || l == 'сирий жовток') return 'Жовток яєчний';
    if (l == 'солі' || l == 'сіль' || l == 'соли') return 'Сіль';
    if (l == 'цукру' || l == 'цукор' || l == 'сахара') return 'Цукор';
    if (l == 'борошна' || l == 'борошно' || l == 'муки' || l == 'мука') {
      return 'Борошно пшеничне';
    }
    if (l == 'манки' || l == 'манка' || l == 'манної крупи') {
      return 'Манна крупа';
    }
    if (l == 'крохмалу' || l == 'крохмаль') return 'Крохмаль';
    if (l.contains('ваніліну або ванільного цукру') || l == 'ваніліну') {
      return 'Ванільний цукор';
    }
    return _capitalize(raw);
  }

  static String _normalizeUnit(String raw) {
    final l = raw.toLowerCase().replaceAll(' ', '');
    if (l.startsWith('ст') ||
        l.startsWith('столов') ||
        l.startsWith('tbsp') ||
        l == 'tbs' ||
        l.startsWith('tablespoon')) {
      return 'ст. л.';
    }
    if (l.startsWith('ч') ||
        l.startsWith('чайн') ||
        l.startsWith('tsp') ||
        l.startsWith('teaspoon')) {
      return 'ч. л.';
    }
    if (l == 'гр' ||
        l == 'г' ||
        l == 'g' ||
        l == 'gr' ||
        l.startsWith('грам') ||
        l.startsWith('gram')) {
      return 'г';
    }
    if (l == 'кг' || l == 'kg') return 'кг';
    if (l == 'мл' || l == 'ml') return 'мл';
    if (l == 'л' || l == 'l') return 'л';
    if (l.startsWith('шт') ||
        l.startsWith('pcs') ||
        l == 'pc' ||
        l.startsWith('piece') ||
        l.startsWith('брикет')) {
      return 'шт';
    }
    if (l.startsWith('зуб') || l.startsWith('clove')) return 'зубч.';
    if (l.startsWith('склян') || l.startsWith('cup')) return 'скл.';
    if (l.startsWith('дріб') || l.startsWith('щіп') || l.startsWith('pinch')) {
      return 'дрібка';
    }
    return raw.trim();
  }

  /// Food vocabulary (Ukrainian / Russian / English word stems) used as the last-resort
  /// ingredient detector over free recipe text, subtitles and on-screen text.
  /// Each entry: (stem regex matched at a word start, display name, default amount, unit).
  static const List<(String, String, double, String)> _proseFoodVocabulary = [
    // Dairy & eggs
    (
      r'(?:кисломолочн|творог|творож|сирник|вареник|cottage cheese)',
      'Сир кисломолочний',
      300,
      'г',
    ),
    (r'(?:пармезан|parmesan)', 'Пармезан', 40, 'г'),
    (r'(?:моцарел|mozzarella)', 'Моцарела', 125, 'г'),
    (r'(?:фет[аиу]\b|бринз|feta)', 'Фета', 100, 'г'),
    (
      r'(?:маскарпоне|філадельф|филадельф|вершковий сир|сливочный сыр|cream cheese)',
      'Вершковий сир',
      150,
      'г',
    ),
    (
      r'(?:твердий сир|твердого сиру|твердый сыр|твердого сыра|сыр\b|сыра\b|сыром\b|cheddar|чеддер|cheese)',
      'Твердий сир',
      100,
      'г',
    ),
    (r'(?:сметан|sour cream)', 'Сметана', 2, 'ст. л.'),
    (r'(?:йогурт|yogh?urt)', 'Йогурт', 150, 'г'),
    (r'(?:кефір|кефир|kefir)', 'Кефір', 250, 'мл'),
    (
      r'(?:вершков\w*\s+масл\w*|сливочн\w*\s+масл\w*|butter)',
      'Вершкове масло',
      30,
      'г',
    ),
    (r'(?:вершк|сливк|heavy cream|cream\b)', 'Вершки', 100, 'мл'),
    (
      r'(?:молок[аоуі]|молоком|milk)(?![а-яіїєґa-z])',
      'Молоко',
      200,
      'мл',
    ),
    (r'(?:яйц|яиц|яєц|яйк|яичк|жовт|желтк|eggs?\b)', 'Яйця курячі', 2, 'шт'),
    // Baking & grains
    (r'(?:борошн|мук[аиуо]\b|flour)', 'Борошно пшеничне', 150, 'г'),
    (r'(?:цукор|цукр|сахар|sugar)', 'Цукор', 1, 'ст. л.'),
    (
      r'(?:ванілін|ванилин|ванільн|ванильн|vanilla)',
      'Ванільний цукор',
      1,
      'ч. л.',
    ),
    (r'(?:крохмал|крахмал|starch|cornstarch)', 'Крохмаль', 1, 'ст. л.'),
    (
      r'(?:розпушувач|разрыхлител|baking powder|сод[аиу]\b|baking soda)',
      'Розпушувач',
      1,
      'ч. л.',
    ),
    (r'(?:дріждж|дрожж|yeast)', 'Дріжджі', 7, 'г'),
    (r'(?:манк|манн|semolina)', 'Манна крупа', 2, 'ст. л.'),
    (r'(?:вівсян|овсян|oats|oatmeal)', 'Вівсяні пластівці', 80, 'г'),
    (r'(?:гречк|гречан|гречнев|buckwheat)', 'Гречка', 150, 'г'),
    (r'(?:рис\b|рису\b|рисом\b|рисов|rice)', 'Рис', 150, 'г'),
    (r'(?:булгур|кус-?кус|couscous|bulgur)', 'Булгур', 150, 'г'),
    (
      r'(?:паст[аиуі]\b|макарон|спагет|пенне|фузил|фузіл|локшин|лапш|noodle|pasta|spaghetti)',
      'Паста',
      180,
      'г',
    ),
    (r'(?:хліб|хлеб|батон|багет|тост|bread|toast)', 'Хліб', 2, 'шт'),
    (r'(?:лаваш|тортиль|tortilla|pita)', 'Лаваш / тортилья', 1, 'шт'),
    // Vegetables & greens
    (
      r'(?:кетчуп\w*|томатн\w*\s+паст\w*|tomato paste|ketchup)',
      'Томатна паста',
      1,
      'ст. л.',
    ),
    (r'(?:картопл|картоф|картошк|potato)', 'Картопля', 400, 'г'),
    (r'(?:моркв|морков|carrot)', 'Морква', 1, 'шт'),
    (r'(?:буряк|свекл|свёкл|beet)', 'Буряк', 1, 'шт'),
    (r'(?:цибул|лук\b|лука\b|луком\b|лучок|лучк|onion)', 'Цибуля', 1, 'шт'),
    (r'(?:часник|чеснок|чесноч|garlic)', 'Часник', 2, 'зубч.'),
    (r'(?:томат|помідор|помидор|tomato)', 'Помідори', 2, 'шт'),
    (r'(?:огір|огірк|огур|cucumber|pickle)', 'Огірок', 1, 'шт'),
    (
      r'(?:болгарськ\w*|болгарск\w*|солодк\w*|сладк\w*)\s+пер[еця]\w*|bell pepper|паприк\w* свіж',
      'Болгарський перець',
      1,
      'шт',
    ),
    (r'(?:кабач|цукін|цукин|zucchini)', 'Кабачок', 1, 'шт'),
    (r'(?:баклажан|eggplant|aubergine)', 'Баклажан', 1, 'шт'),
    (r'(?:брокол|broccoli)', 'Броколі', 200, 'г'),
    (r'(?:капуст|cabbage)', 'Капуста', 300, 'г'),
    (r'(?:шпинат|spinach)', 'Шпинат', 100, 'г'),
    (r'(?:гриб|печериц|шампіньйон|шампиньон|mushroom)', 'Печериці', 250, 'г'),
    (r'(?:кукурудз|кукуруз|corn\b)', 'Кукурудза', 100, 'г'),
    (r'(?:горош|peas)', 'Зелений горошок', 100, 'г'),
    (r'(?:квасол|фасол|beans)', 'Квасоля', 200, 'г'),
    (r'(?:нут\b|нуту\b|chickpea)', 'Нут', 200, 'г'),
    (r'(?:сочевиц|чечевиц|lentil)', 'Сочевиця', 150, 'г'),
    (
      r'(?:кріп|кропу|укроп|петрушк|кінз|кинз|зелен|руккол|dill|parsley|cilantro)',
      'Зелень',
      1,
      'пучок',
    ),
    (r'(?:базилік|базилик|basil)', 'Базилік', 1, 'пучок'),
    (r'(?:авокадо|avocado)', 'Авокадо', 1, 'шт'),
    // Fruit
    (r'(?:лимон|лайм|lemon|lime)', 'Лимон', 1, 'шт'),
    (r'(?:банан|banana)', 'Банан', 1, 'шт'),
    (r'(?:яблук|яблок|яблоч|apple)', 'Яблуко', 1, 'шт'),
    (
      r'(?:ягід|ягод|полуниц|клубник|малин|лохин|чорниц|черник|вишн|berr)',
      'Ягоди',
      150,
      'г',
    ),
    // Meat & fish
    (r'(?:куряч|курин|курк|куриц|курочк|chicken)', 'Курка', 400, 'г'),
    (r'(?:індич|индей|индюш|turkey)', 'Індичка', 400, 'г'),
    (r'(?:ялович|говядин|телятин|beef|veal)', 'Яловичина', 400, 'г'),
    (r'(?:фарш|minced|ground meat)', 'Фарш', 400, 'г'),
    (r'(?:свинин|свинят|pork)', 'Свинина', 400, 'г'),
    (r'(?:бекон|bacon)', 'Бекон', 100, 'г'),
    (
      r'(?:(?:ковбас[аиуоії]|колбас[аыуое]|шинк[аиуою])(?![а-яіїєґa-z])|сосиск|сардельк|ветчин|sausage|ham(?![a-z]))',
      'Ковбаса / шинка',
      150,
      'г',
    ),
    (r'(?:баранин|бараш|ягнят|ягнен|lamb)', 'Баранина', 400, 'г'),
    (r'(?:лосос|сьомг|семг|форел|salmon|trout)', 'Лосось', 300, 'г'),
    (r'(?:оселед|селед|сельд|herring)', 'Оселедець', 1, 'шт'),
    (r'(?:тунц|тунец|tuna)', 'Тунець', 1, 'банка'),
    (r'(?:риб[аиуоі]|рыб|fish)', 'Риба', 400, 'г'),
    (r'(?:креветк|shrimp|prawn)', 'Креветки', 250, 'г'),
    // Pantry
    (
      r'(?:оливков\w*(?:\s+(?:олі|масл)\w*)?|olive oil)',
      'Оливкова олія',
      2,
      'ст. л.',
    ),
    (
      r'(?:олі[яїю]|соняшников\w*|растительн\w*\s+масл\w*|подсолнечн\w*(?:\s+масл\w*)?|oil\b)',
      'Олія',
      2,
      'ст. л.',
    ),
    (r'(?:мед\b|меду\b|медом\b|honey)', 'Мед', 1, 'ст. л.'),
    (r'(?:шоколад|какао|chocolate|cocoa)', 'Шоколад', 50, 'г'),
    (
      r'(?:горіх|орех|волоськ|грецк\w* орех|nuts?\b|walnut|almond|мигдал|миндал)',
      'Горіхи',
      50,
      'г',
    ),
    (r'(?:майонез|mayo)', 'Майонез', 2, 'ст. л.'),
    (r'(?:гірчиц|горчиц|mustard)', 'Гірчиця', 1, 'ч. л.'),
    (r'(?:соєв\w* соус|соев\w* соус|soy sauce)', 'Соєвий соус', 2, 'ст. л.'),
    (r'(?:оцт|уксус|vinegar)', 'Оцет', 1, 'ст. л.'),
    (r'(?:сіль|солі\b|соль\b|соли\b|посол|salt)', 'Сіль', 1, 'дрібка'),
    (
      r'(?:чорн\w* перц|черн\w* перц|перец\b|перцем\b|black pepper|pepper)',
      'Перець мелений',
      1,
      'дрібка',
    ),
    (r'(?:паприк|paprika)', 'Паприка', 1, 'ч. л.'),
    (r'(?:кориц|cinnamon)', 'Кориця', 1, 'ч. л.'),
  ];

  static List<RecipeIngredient> _extractImplicitIngredientsFromProse(
    String prose,
    List<PantryItem> currentPantry,
    Set<String> ownedKeys,
  ) {
    final found = <RecipeIngredient>[];
    // Strip negated mentions ("без борошна", "без манки", "не додаю цукру", "without flour")
    var lower = prose
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(
          RegExp(
            r'(?<![а-яіїєґa-z])(?:без|ніяк[а-яіїєґ]*|не\s+дода[а-яіїєґ]*|не\s+бер[а-яіїєґ]*|не\s+треба|without|no)\s+(?:[а-яіїєґa-z]+\s+){0,2}[а-яіїєґa-z]+',
          ),
          ' ',
        );
    const wordStart = r'(?<![а-яіїєґёa-z])';
    final hits = <(int, RecipeIngredient)>[];
    final usedNames = <String>{};

    for (final entry in _proseFoodVocabulary) {
      // Dart's \w is ASCII-only, so expand it to cover Cyrillic letters too
      final pattern = entry.$1.replaceAll(r'\w', '[а-яіїєґёa-z]');
      final match = RegExp(
        '$wordStart$pattern',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(lower);
      if (match == null || usedNames.contains(entry.$2)) continue;
      usedNames.add(entry.$2);
      // Consume the matched phrase so generic stems ("перець", "томат", "олія") don't double-count it
      lower = lower.replaceRange(
        match.start,
        match.end,
        ' ' * (match.end - match.start),
      );
      final key = _canonicalizeWithEnglishSupport(entry.$2, currentPantry);
      hits.add((
        match.start,
        RecipeIngredient(
          name: entry.$2,
          canonicalKey: key,
          baseAmount: entry.$3,
          unit: entry.$4,
          prepNote: ownedKeys.contains(key)
              ? 'Є у вашому холодильнику'
              : 'Розпізнано з мовлення / тексту відео',
        ),
      ));
    }

    // Keep the order in which ingredients are mentioned in the video
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    for (final h in hits) {
      if (!found.any(
        (e) =>
            e.canonicalKey == h.$2.canonicalKey &&
            h.$2.canonicalKey != 'ingredient' &&
            e.name == h.$2.name,
      )) {
        found.add(h.$2);
      }
    }
    return found;
  }

  /// Culinary Dish Knowledge Graph: infers canonical essential ingredients when a video
  /// has NO description or only names the dish (e.g. "Деруни", "Карбонара", "Ліниві вареники", "Вівсяномлинець").
  static const List<(String, List<(String, double, String)>)>
  _dishKnowledgeGraph = [
    (
      r'(?:ліниві\s*вареник|лінивих\s*вареник|ленивые\s*вареник)',
      [
        ('Сир кисломолочний', 300, 'г'),
        ('Яйце куряче', 1, 'шт'),
        ('Борошно пшеничне', 4, 'ст. л.'),
        ('Цукор', 1, 'ст. л.'),
        ('Сіль', 1, 'дрібка'),
      ],
    ),
    (
      r'(?:сирник|сырник)',
      [
        ('Сир кисломолочний', 350, 'г'),
        ('Яйце куряче', 1, 'шт'),
        ('Борошно пшеничне', 3, 'ст. л.'),
        ('Цукор', 1.5, 'ст. л.'),
        ('Ванільний цукор', 1, 'ч. л.'),
      ],
    ),
    (
      r'(?:дерун|драник)',
      [
        ('Картопля', 500, 'г'),
        ('Цибуля', 1, 'шт'),
        ('Яйце куряче', 1, 'шт'),
        ('Борошно пшеничне', 2, 'ст. л.'),
        ('Сметана', 2, 'ст. л.'),
        ('Олія', 2, 'ст. л.'),
      ],
    ),
    (
      r'(?:вівсяномлин|овсяноблин)',
      [
        ('Вівсяні пластівці', 60, 'г'),
        ('Яйця курячі', 2, 'шт'),
        ('Молоко', 60, 'мл'),
        ('Твердий сир', 50, 'г'),
      ],
    ),
    (
      r'(?:налисник|млинц|блинчик|блины|crepes?)',
      [
        ('Молоко', 500, 'мл'),
        ('Яйця курячі', 2, 'шт'),
        ('Борошно пшеничне', 200, 'г'),
        ('Цукор', 1, 'ст. л.'),
        ('Олія', 2, 'ст. л.'),
      ],
    ),
    (
      r'(?:оладк|оладь|панкейк|pancakes?)',
      [
        ('Кефір', 250, 'мл'),
        ('Яйце куряче', 1, 'шт'),
        ('Борошно пшеничне', 180, 'г'),
        ('Цукор', 1.5, 'ст. л.'),
        ('Розпушувач', 1, 'ч. л.'),
      ],
    ),
    (
      r'(?:шакшук|shakshuka)',
      [
        ('Яйця курячі', 4, 'шт'),
        ('Томати чері', 250, 'г'),
        ('Болгарський перець', 1, 'шт'),
        ('Часник', 2, 'зубч.'),
        ('Оливкова олія', 2, 'ст. л.'),
      ],
    ),
    (
      r'(?:карбонар|carbonara)',
      [
        ('Паста', 200, 'г'),
        ('Бекон', 120, 'г'),
        ('Яйця курячі', 2, 'шт'),
        ('Пармезан', 50, 'г'),
        ('Перець мелений', 1, 'дрібка'),
      ],
    ),
    (
      r'(?:болоньєз|болоньез|bolognese)',
      [
        ('Паста', 200, 'г'),
        ('Фарш', 350, 'г'),
        ('Помідори', 250, 'г'),
        ('Цибуля', 1, 'шт'),
        ('Часник', 2, 'зубч.'),
        ('Пармезан', 30, 'г'),
      ],
    ),
    (
      r'(?:салат\s*цезар|цезар|caesar\s*salad)',
      [
        ('Куряче філе', 250, 'г'),
        ('Пармезан', 40, 'г'),
        ('Томати чері', 120, 'г'),
        ('Хліб', 2, 'шт'),
        ('Яйце куряче', 1, 'шт'),
      ],
    ),
    (
      r'(?:грецький\s*салат|греческий\s*салат|greek\s*salad)',
      [
        ('Помідори', 2, 'шт'),
        ('Огірок', 2, 'шт'),
        ('Болгарський перець', 1, 'шт'),
        ('Фета', 120, 'г'),
        ('Оливкова олія', 2, 'ст. л.'),
      ],
    ),
    (
      r'(?:гуакамоле|guacamole|авокадо\s*тост|avocado\s*toast)',
      [
        ('Авокадо', 2, 'шт'),
        ('Лимон', 0.5, 'шт'),
        ('Хліб', 2, 'шт'),
        ('Яйця курячі', 2, 'шт'),
        ('Томати чері', 80, 'г'),
      ],
    ),
    (
      r'(?:шарлотк)',
      [
        ('Яблуко', 4, 'шт'),
        ('Яйця курячі', 4, 'шт'),
        ('Цукор', 150, 'г'),
        ('Борошно пшеничне', 150, 'г'),
        ('Кориця', 1, 'ч. л.'),
      ],
    ),
    (
      r'(?:омлет|скрембл|omelet|scrambled)',
      [
        ('Яйця курячі', 3, 'шт'),
        ('Молоко', 50, 'мл'),
        ('Вершкове масло', 15, 'г'),
        ('Твердий сир', 40, 'г'),
      ],
    ),
    (
      r'(?:борщ\b|борщу)',
      [
        ('Буряк', 2, 'шт'),
        ('Картопля', 300, 'г'),
        ('Капуста', 250, 'г'),
        ('Морква', 1, 'шт'),
        ('Цибуля', 1, 'шт'),
        ('Томатна паста', 2, 'ст. л.'),
      ],
    ),
  ];

  static List<RecipeIngredient> _inferCanonicalDishIngredients(
    String dishContext,
    List<PantryItem> currentPantry,
    Set<String> ownedKeys,
  ) {
    final lower = dishContext.toLowerCase();
    for (final entry in _dishKnowledgeGraph) {
      if (RegExp(entry.$1, caseSensitive: false, unicode: true).hasMatch(lower)) {
        return entry.$2.map((item) {
          final key = _canonicalizeWithEnglishSupport(item.$1, currentPantry);
          final sub = IngredientNormalizer.suggestSubstitution(key, ownedKeys);
          return RecipeIngredient(
            name: item.$1,
            canonicalKey: key,
            baseAmount: item.$2,
            unit: item.$3,
            prepNote: ownedKeys.contains(key)
                ? 'Є у вашому холодильнику'
                : 'Автоматично доповнено за назвою страви',
            substituteKey: sub.$1,
            substituteTip: sub.$2,
          );
        }).toList();
      }
    }
    return const [];
  }

  static List<CookingStep> _buildStepsFromProse(
    List<String> proseLines,
    String title,
    List<RecipeIngredient> ingredients,
  ) {
    final steps = <CookingStep>[];

    // Expand long unpunctuated ASR transcript chunks into coherent cooking clauses
    final expandedProse = <String>[];
    for (final raw in proseLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length > 140 && !RegExp(r'[.!?]').hasMatch(trimmed)) {
        final chunks = trimmed
            .split(
              RegExp(
                r'(?=\b(?:тепер|далі|потім|після цього|формуємо|сформуйте|обсмажуємо|смажимо|смажте|відварюємо|варимо|запікаємо|випікаємо|подаємо|подавайте|then|next|now\s+(?:fry|bake|boil|mix|shape))\b)',
                caseSensitive: false,
                unicode: true,
              ),
            )
            .map((s) => s.trim())
            .where((s) => s.length >= 10);
        expandedProse.addAll(chunks);
      } else {
        expandedProse.add(trimmed);
      }
    }

    bool sameAsTitle(String s) {
      final normA = s
          .toLowerCase()
          .replaceAll(RegExp(r'[^а-яіїєґa-z0-9]+'), '')
          .trim();
      final normB = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^а-яіїєґa-z0-9]+'), '')
          .trim();
      return normA.isEmpty || normA == normB;
    }

    final firstNonTitleTip = expandedProse.firstWhere(
      (l) => !sameAsTitle(l) && !_isSocialBoilerplateLine(l),
      orElse: () => '',
    );

    // Step 1: Always provide a clear Mise-en-place / Dough / Prep step from the parsed ingredients
    final mainIngs = ingredients
        .take(5)
        .map((e) => e.name.toLowerCase())
        .join(', ');
    final prepInstruction =
        'Підготуйте та поєднайте інгредієнти для страви «$title»: $mainIngs до однорідної текстури.';
    final prepSeconds = (ingredients.length >= 6 ? 240 : 180);
    steps.add(
      CookingStep(
        shortTitle:
            'Підготовка основи (~${CookingStep.formatApproxMinutes(prepSeconds)})',
        instruction: prepInstruction,
        detailTip: firstNonTitleTip.isNotEmpty && firstNonTitleTip.length <= 130
            ? _capitalize(firstNonTitleTip)
            : 'Орієнтовний час підготовки (~${CookingStep.formatApproxMinutes(prepSeconds)}) розраховано автоматично за кількістю складників.',
        heatLabel: 'Підготовка',
        timerSeconds: prepSeconds,
        isTimerEstimated: true,
      ),
    );

    List<String> actionLines = expandedProse
        .where((l) => !sameAsTitle(l) && !_isSocialBoilerplateLine(l))
        .toList();
    if (actionLines.length > 1 && actionLines.first == firstNonTitleTip && !_looksLikeCookingAction(firstNonTitleTip) && CookingStep.extractExplicitSeconds(firstNonTitleTip) == null) {
      actionLines = actionLines.sublist(1);
    }
    if (actionLines.length > 9) {
      final filtered = actionLines
          .where(
            (l) =>
                _looksLikeCookingAction(l) ||
                CookingStep.extractExplicitSeconds(l) != null,
          )
          .take(7)
          .toList();
      if (filtered.isNotEmpty) {
        actionLines = filtered;
      } else {
        actionLines = actionLines.take(6).toList();
      }
    }
    for (int i = 0; i < actionLines.length; i++) {
      final line = _capitalize(_stripStepNumberPrefix(actionLines[i]).trim());
      if (line.length < 8 || _isSocialBoilerplateLine(line) || sameAsTitle(line)) {
        continue;
      }

      final lower = line.toLowerCase();
      final heat =
          lower.contains('закипан') ||
                  lower.contains('варит') ||
                  lower.contains('варю') ||
                  lower.contains('boil') ||
                  lower.contains('simmer')
              ? 'Кипляча вода'
              : (lower.contains('смаж') ||
                        lower.contains('масл') ||
                        lower.contains('пательн') ||
                        lower.contains('сковород') ||
                        lower.contains('fry') ||
                        lower.contains('skillet') ||
                        lower.contains('pan'))
                  ? 'Середній вогонь'
                  : (lower.contains('духов') ||
                            lower.contains('запік') ||
                            lower.contains('випік') ||
                            lower.contains('bake') ||
                            lower.contains('oven'))
                      ? 'Духовка'
                      : 'Готування';

      final (resolvedSec, isEstimated) = CookingStep.resolveDuration(
        instruction: line,
        heatLabel: heat,
      );
      final stageLabel = CookingStep.inferActionTitle(
        line,
        stepNumber: steps.length + 1,
      );
      final timeBadge = CookingStep.formatApproxMinutes(resolvedSec);
      final shortName = isEstimated
          ? '$stageLabel (~$timeBadge)'
          : '$stageLabel ($timeBadge)';

      steps.add(
        CookingStep(
          shortTitle: shortName,
          instruction: RegExp(r'[.!?]$').hasMatch(line) ? line : '$line.',
          detailTip: isEstimated
              ? 'Точний час у відео не названо — Crisper оцінив тривалість цього кроку приблизно у ~$timeBadge.'
              : 'Натисніть «Старт» на таймері нижче для точного контролю часу за рецептом.',
          heatLabel: heat,
          timerSeconds: resolvedSec,
          isTimerEstimated: isEstimated,
        ),
      );
    }

    if (steps.length == 1) {
      final finishInstruction = firstNonTitleTip.isNotEmpty
          ? _capitalize(firstNonTitleTip)
          : 'Доведіть «$title» до повної готовності та подавайте теплим.';
      final (sec, est) = CookingStep.resolveDuration(
        instruction: '$title $finishInstruction',
        heatLabel: 'Середній вогонь',
      );
      final timeBadge = CookingStep.formatApproxMinutes(sec);
      steps.add(
        CookingStep(
          shortTitle: est
              ? 'Приготування та подача (~$timeBadge)'
              : 'Приготування та подача ($timeBadge)',
          instruction: finishInstruction,
          detailTip: est
              ? 'Орієнтовний час (~$timeBadge) підібрано автоматично відповідно до типу страви.'
              : 'Прикрасьте улюбленими додатками з вашого холодильника.',
          heatLabel: 'Середній вогонь',
          timerSeconds: sec,
          isTimerEstimated: est,
        ),
      );
    }

    return steps;
  }

  static List<CookingStep> _parseLdInstructions(dynamic rawInst) {
    final out = <CookingStep>[];
    void addStepText(String rawText) {
      final clean = _unescapeHtml(rawText.trim());
      if (clean.length <= 5) return;
      final (sec, est) = CookingStep.resolveDuration(instruction: clean);
      final stage = CookingStep.inferActionTitle(
        clean,
        stepNumber: out.length + 1,
      );
      final badge = CookingStep.formatApproxMinutes(sec);
      out.add(
        CookingStep(
          shortTitle: est ? '$stage (~$badge)' : '$stage ($badge)',
          instruction: clean,
          detailTip: est
              ? 'Орієнтовний час кроку (~$badge) оцінено автоматично.'
              : '',
          heatLabel: 'Готування',
          timerSeconds: sec,
          isTimerEstimated: est,
        ),
      );
    }

    if (rawInst is String && rawInst.trim().isNotEmpty) {
      for (final p in rawInst.split(RegExp(r'\r?\n+'))) {
        addStepText(p);
      }
    } else if (rawInst is List) {
      for (final item in rawInst) {
        String? text;
        if (item is String) text = item;
        if (item is Map<String, dynamic>) {
          text = (item['text'] as String?) ?? (item['name'] as String?);
        }
        if (text != null && text.trim().isNotEmpty) {
          addStepText(text);
        }
      }
    }
    return out;
  }

  static List<CookingStep> _buildFallbackStepsFromIngredients(
    String title,
    List<RecipeIngredient> ingredients,
  ) {
    final mainCookSec = CookingStep.estimateDurationSeconds(
      instruction: 'Обсмажте або приготуйте $title до готовності',
      heatLabel: 'Середній вогонь',
    );
    return [
      CookingStep(
        shortTitle: 'Підготовка інгредієнтів (~3 хв)',
        instruction:
            'Зберіть необхідні складові для «$title»: ${ingredients.take(4).map((e) => e.name.toLowerCase()).join(', ')}.',
        detailTip: 'Орієнтовний час підготовки оцінено автоматично (~3 хв).',
        heatLabel: 'Підготовка',
        timerSeconds: 180,
        isTimerEstimated: true,
      ),
      CookingStep(
        shortTitle:
            'Основне приготування (~${CookingStep.formatApproxMinutes(mainCookSec)})',
        instruction:
            'Поєднайте підготовлені інгредієнти та готуйте «$title» до повної готовності.',
        detailTip:
            'Орієнтовний час кроку (~${CookingStep.formatApproxMinutes(mainCookSec)}) оцінено автоматично.',
        heatLabel: 'Середній вогонь',
        timerSeconds: mainCookSec,
        isTimerEstimated: true,
      ),
    ];
  }

  static String _buildSousChefTip(
    List<RecipeIngredient> ingredients,
    Set<String> ownedKeys,
  ) {
    for (final ing in ingredients) {
      if (!ownedKeys.contains(ing.canonicalKey) && ing.substituteTip != null) {
        return ing.substituteTip!;
      }
    }
    if (ownedKeys.contains('greek_yogurt') &&
        ingredients.any((i) => i.canonicalKey == 'cottage_cheese')) {
      return 'Подавайте готову страву з ложкою вашого охолодженого грецького йогурту замість сметани — це підкреслить ніжний вершковий смак і врятує відкриту баночку!';
    }
    final ownedCount = ingredients
        .where((i) => ownedKeys.contains(i.canonicalKey))
        .length;
    return 'У вашому холодильнику вже є $ownedCount з ${ingredients.length} необхідних інгредієнтів для цього рецепта.';
  }

  static int? _parseIsoDurationMinutes(String? iso) {
    if (iso == null) return null;
    final h = RegExp(r'(\d+)H').firstMatch(iso);
    final m = RegExp(r'(\d+)M').firstMatch(iso);
    final hours = h != null ? int.tryParse(h.group(1)!) ?? 0 : 0;
    final mins = m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
    final total = hours * 60 + mins;
    return total > 0 ? total : null;
  }

  static String? _extractMetaContent(String html, String propOrName) {
    final escapedName = RegExp.escape(propOrName);
    // Match double-quoted and single-quoted attributes separately so apostrophes inside content="..." never truncate!
    final patterns = [
      RegExp(
        '<meta[^>]+(?:property|name)=["\x27]$escapedName["\x27][^>]+content="([^"]*)"',
        caseSensitive: false,
      ),
      RegExp(
        "<meta[^>]+(?:property|name)=[\"\x27]$escapedName[\"\x27][^>]+content='([^']*)'",
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content="([^"]*)"[^>]+(?:property|name)=["\x27]$escapedName["\x27]',
        caseSensitive: false,
      ),
      RegExp(
        "<meta[^>]+content='([^']*)'[^>]+(?:property|name)=[\"\x27]$escapedName[\"\x27]",
        caseSensitive: false,
      ),
    ];
    for (final rx in patterns) {
      final m = rx.firstMatch(html);
      if (m != null && m.group(1)!.isNotEmpty) return m.group(1);
    }
    return null;
  }

  static String? _extractHtmlTitle(String html) {
    final m = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return m?.group(1)?.trim();
  }

  static String _cleanSocialVideoTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'#[^\s#]+'), '')
        .replaceAll(RegExp(r'\s*\|\s*[^|]{2,35}$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static String _normalizeTitleCase(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return trimmed;
    final letters = RegExp(
      r'[A-ZА-ЯІЇЄҐa-zа-яіїєґ]',
    ).allMatches(trimmed).map((m) => m.group(0)!).toList();
    final upperCount = letters
        .where((c) => c == c.toUpperCase() && c != c.toLowerCase())
        .length;
    if (letters.length >= 4 && upperCount > letters.length * 0.7) {
      return _capitalize(trimmed.toLowerCase());
    }
    // Also normalize if first word alone is ALL CAPS ("СИРНИКИ - ідеальні пропорції")
    final parts = trimmed.split(' ');
    if (parts.first.length >= 4 &&
        parts.first == parts.first.toUpperCase() &&
        parts.first != parts.first.toLowerCase()) {
      parts[0] = _capitalize(parts.first.toLowerCase());
      return parts.join(' ');
    }
    return _capitalize(trimmed);
  }

  static String _unescapeHtml(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1)!, radix: 16);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1)!);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        });
  }

  static String _humanizeHashtag(String tag) {
    if (tag.toLowerCase() == 'лінивівареники') return 'Ліниві вареники';
    if (tag.toLowerCase() == 'гарбузянісирники') return 'Гарбузяні сирники';
    return _capitalize(tag.replaceAll('_', ' '));
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
