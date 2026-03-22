import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/features/economy/providers/economy_provider.dart';

class MagnumBannerAd extends ConsumerStatefulWidget {
  const MagnumBannerAd({super.key});

  @override
  ConsumerState<MagnumBannerAd> createState() => _MagnumBannerAdState();
}

class _MagnumBannerAdState extends ConsumerState<MagnumBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  final String _adUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Google test banner ad unit ID

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final isPro = ref.read(economyProvider).isPro;
    if (isPro) return;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(economyProvider).isPro;
    if (isPro || _bannerAd == null || !_isLoaded) {
      return const SizedBox(width: 0, height: 0);
    }

    return Container(
      color: Colors.black,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
