import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/shop_catalog.dart';
import '../models/app_store.dart';
import '../models/shop_purchase.dart';
import '../models/shop_reward.dart';
import '../services/profile_photo_service.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import 'main_shell.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ShopService _shopService = ShopService();
  bool _purchaseBusy = false;

  Set<String> _hiddenSet(AppStore store) =>
      store.userProfile.shopHiddenBuiltinIds.toSet();

  List<ShopReward> _visibleBuiltins(Set<String> hidden) {
    return kDefaultShopRewards
        .where((r) => !hidden.contains(r.id))
        .toList(growable: false);
  }

  String _fmtPurchase(DateTime? d) {
    if (d == null) return 'Дата уточняется';
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$day.$month.${d.year} $h:$m';
  }

  Future<void> _buy(ShopReward item, int coins) async {
    if (_purchaseBusy || coins < item.price) return;
    setState(() => _purchaseBusy = true);
    try {
      await _shopService.purchaseReward(
        rewardId: item.id,
        title: item.title,
        price: item.price,
        isBuiltin: item.isBuiltin,
      );
      if (!mounted) return;
      await _showPurchaseCelebration(item);
    } on ShopInsufficientCoinsException {
      if (!mounted) return;
      MainShell.of(context).showToast('Недостаточно монет', isError: true);
    } catch (e, st) {
      debugPrint('Shop purchase: $e\n$st');
      if (!mounted) return;
      MainShell.of(context)
          .showToast('Не удалось оформить покупку', isError: true);
    } finally {
      if (mounted) setState(() => _purchaseBusy = false);
    }
  }

  Future<void> _showPurchaseCelebration(ShopReward item) async {
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (ctx) => _PurchaseCelebrationDialog(item: item),
    );
  }

  Future<void> _hideBuiltin(String id) async {
    try {
      await _shopService.hideBuiltinReward(id);
      if (!mounted) return;
      MainShell.of(context).showToast('Награда скрыта из списка');
    } catch (e, st) {
      debugPrint('hideBuiltin: $e\n$st');
      if (!mounted) return;
      MainShell.of(context).showToast('Ошибка сохранения', isError: true);
    }
  }

  Future<void> _confirmDeleteCustom(ShopReward r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить награду?'),
        content: Text('«${r.title}» исчезнет из магазина.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _shopService.deleteCustomReward(r.id);
      if (!mounted) return;
      MainShell.of(context).showToast('Награда удалена');
    } catch (e, st) {
      debugPrint('deleteCustom: $e\n$st');
      if (!mounted) return;
      MainShell.of(context).showToast('Не удалось удалить', isError: true);
    }
  }

  Future<void> _showCreateRewardDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _CreateShopRewardSheet(
        shopService: _shopService,
        onSuccess: () {
          Navigator.of(sheetCtx).pop();
          if (mounted) MainShell.of(context).showToast('Награда добавлена');
        },
        onError: (msg) {
          if (mounted) MainShell.of(context).showToast(msg, isError: true);
        },
      ),
    );
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      const Text(
                        'История покупок',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ShopPurchase>>(
                    stream: _shopService.watchPurchases(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            'Покупок пока нет',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final p = list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            color: AppColors.bgMain,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppColors.borderDark),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.redeem_rounded,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${_fmtPurchase(p.purchasedAt)} · ${p.price} мон.',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => MainShell.of(context).setIndex(0),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Магазин наград',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'История покупок',
                    onPressed: _openHistory,
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: AppStore.instance,
                builder: (context, _) {
                  final store = AppStore.instance;
                  final coins = store.userProfile.coins;
                  final builtins = _visibleBuiltins(_hiddenSet(store));
                  return StreamBuilder<List<ShopReward>>(
                    stream: _shopService.watchCustomRewards(),
                    builder: (context, snap) {
                      final custom = snap.data ?? [];
                      final all = [...builtins, ...custom];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFA855F7),
                                    Color(0xFF7E22CE),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x4D9333EA),
                                    blurRadius: 30,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Ваш текущий баланс',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$coins',
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.toll_rounded,
                                          color: AppColors.yellow,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Доступные награды',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Material(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    onTap: _showCreateRewardDialog,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.add_circle_rounded,
                                            color: AppColors.primaryDark,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Своя награда',
                                            style: TextStyle(
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (snap.connectionState ==
                                    ConnectionState.waiting &&
                                !snap.hasData)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (all.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 48,
                                ),
                                child: Center(
                                  child: Text(
                                    'Нет наград в витрине.\nСоздайте свою кнопкой «Своя награда».',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: all.length,
                                itemBuilder: (_, i) {
                                  final item = all[i];
                                  return _ShopItemCard(
                                    item: item,
                                    userCoins: coins,
                                    purchaseBusy: _purchaseBusy,
                                    onBuy: () => _buy(item, coins),
                                    onRemoveBuiltin: item.isBuiltin
                                        ? () => _hideBuiltin(item.id)
                                        : null,
                                    onDeleteCustom: !item.isBuiltin
                                        ? () => _confirmDeleteCustom(item)
                                        : null,
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopReward item;
  final int userCoins;
  final bool purchaseBusy;
  final VoidCallback onBuy;
  final VoidCallback? onRemoveBuiltin;
  final VoidCallback? onDeleteCustom;

  const _ShopItemCard({
    required this.item,
    required this.userCoins,
    required this.purchaseBusy,
    required this.onBuy,
    this.onRemoveBuiltin,
    this.onDeleteCustom,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = userCoins >= item.price;
    final buyEnabled = canAfford && !purchaseBusy;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 10),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.hasImage)
                  Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(),
                  )
                else
                  _imageFallback(),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'hide') onRemoveBuiltin?.call();
                        if (v == 'del') onDeleteCustom?.call();
                      },
                      itemBuilder: (ctx) => [
                        if (onRemoveBuiltin != null)
                          const PopupMenuItem(
                            value: 'hide',
                            child: Text('Убрать из магазина'),
                          ),
                        if (onDeleteCustom != null)
                          const PopupMenuItem(
                            value: 'del',
                            child: Text('Удалить награду'),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: item.isBuiltin
                          ? AppColors.borderDark.withValues(alpha: 0.25)
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.isBuiltin ? 'Подборка' : 'Своя',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A000000), blurRadius: 5),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.price}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.toll_rounded,
                          color: AppColors.yellow,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: buyEnabled ? onBuy : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      canAfford ? 'Купить' : 'Не хватает монет',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.primaryLight,
      child: Icon(
        Icons.card_giftcard_rounded,
        color: AppColors.primary,
        size: 40,
      ),
    );
  }
}

class _CreateShopRewardSheet extends StatefulWidget {
  final ShopService shopService;
  final VoidCallback onSuccess;
  final void Function(String message) onError;

  const _CreateShopRewardSheet({
    required this.shopService,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_CreateShopRewardSheet> createState() => _CreateShopRewardSheetState();
}

class _CreateShopRewardSheetState extends State<_CreateShopRewardSheet> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _priceC = TextEditingController(text: '50');
  final _picker = ImagePicker();

  Uint8List? _imagePreview;
  XFile? _pickedFile;
  bool _submitting = false;
  bool _uploadingImage = false;

  InputDecoration _fieldDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: AppColors.bgMain,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
    );
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _priceC.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        widget.onError('Фото слишком большое (макс. 8 МБ)');
        return;
      }
      setState(() {
        _pickedFile = file;
        _imagePreview = bytes;
      });
    } catch (e, st) {
      debugPrint('pickImage: $e\n$st');
      if (mounted) widget.onError('Не удалось выбрать фото');
    }
  }

  void _clearImage() {
    setState(() {
      _pickedFile = null;
      _imagePreview = null;
    });
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      widget.onError('Введите название награды');
      return;
    }
    final price = int.tryParse(_priceC.text.trim()) ?? 0;
    if (price < 1) {
      widget.onError('Цена от 1 монеты');
      return;
    }

    setState(() => _submitting = true);
    try {
      String? imageUrl;
      if (_pickedFile != null) {
        setState(() => _uploadingImage = true);
        try {
          imageUrl = await ProfilePhotoService.instance
              .uploadShopRewardImage(_pickedFile!);
        } finally {
          if (mounted) setState(() => _uploadingImage = false);
        }
      }

      await widget.shopService.addCustomReward(
        title: title,
        description: _descC.text.trim(),
        price: price,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      widget.onSuccess();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      widget.onError(e.message?.toString() ?? 'Проверьте поля');
    } catch (e, st) {
      debugPrint('addCustomReward: $e\n$st');
      if (!mounted) return;
      widget.onError('Не удалось сохранить');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 10, 22, 20 + safeBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryLight,
                          AppColors.primary.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.redeem_rounded,
                      color: AppColors.primaryDark,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Новая награда',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Придумай награду за свои монеты — её увидишь только ты.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Фото (по желанию)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Material(
                  color: AppColors.bgMain,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _submitting ? null : _pickImage,
                    child: _imagePreview != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _imagePreview!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed:
                                        _submitting ? null : _clearImage,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 42,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Нажми, чтобы выбрать из галереи',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Без фото — будет значок подарка',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              if (_uploadingImage) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Загружаем фото…',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              TextField(
                controller: _titleC,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDeco('Название', hint: 'Например, кофе в любимой кофейне'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descC,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDeco('Описание', hint: 'За что награждаешь себя'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _priceC,
                keyboardType: TextInputType.number,
                decoration: _fieldDeco('Цена в монетах', hint: 'от 1'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.borderDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Отмена',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Создать награду',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseCelebrationDialog extends StatelessWidget {
  final ShopReward item;

  const _PurchaseCelebrationDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final price = item.price;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: AppColors.bgWhite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFA855F7),
                        Color(0xFF7E22CE),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.celebration_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 26,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Награда твоя!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Заслужил — забери',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                  child: Column(
                    children: [
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          height: 1.25,
                        ),
                      ),
                      if (item.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.toll_rounded,
                              color: AppColors.warning,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '−$price монет',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              '  с баланса',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Запись есть в истории покупок',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Супер!',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
