import '../models/shop_reward.dart';

/// Встроенные награды (id стабильны — скрытие хранится в профиле).
const List<ShopReward> kDefaultShopRewards = [
  ShopReward(
    id: 's1',
    title: 'Посмотреть фильм',
    description: 'Вечерний киносеанс',
    price: 50,
    imageUrl:
        'https://images.unsplash.com/photo-1585647347384-2593bc35786b?auto=format&fit=crop&q=80&w=300&h=200',
    isBuiltin: true,
  ),
  ShopReward(
    id: 's2',
    title: 'Заказать пиццу',
    description: 'Любимый вкус',
    price: 200,
    imageUrl:
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&q=80&w=300&h=200',
    isBuiltin: true,
  ),
  ShopReward(
    id: 's3',
    title: '1 час видеоигр',
    description: 'Время для отдыха',
    price: 100,
    imageUrl:
        'https://images.unsplash.com/photo-1593305841991-05c297ba4575?auto=format&fit=crop&q=80&w=300&h=200',
    isBuiltin: true,
  ),
];
