import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class IconPickerResult {
  const IconPickerResult({
    required this.iconName,
    required this.colorHex,
  });

  final String iconName;
  final String colorHex;
}

class AppIconItem {
  const AppIconItem({
    required this.name,
    required this.label,
    required this.categoryId,
    required this.icon,
  });

  final String name;
  final String label;
  final String categoryId;
  // `Icons.*` gives `IconData` but `font_awesome_flutter` gives `FaIconData`.
  // Keep this dynamic so we can render either.
  final dynamic icon;
}

class AppIconPickerDialog extends StatefulWidget {
  const AppIconPickerDialog({
    super.key,
    required this.initialIconName,
    required this.initialColorHex,
    this.title = 'تخصيص الأيقونة',
    this.name,
  });

  final String initialIconName;
  final String initialColorHex;
  final String title;
  final String? name;

  static const categoryLabels = <String, String>{
    'all': 'عام',
    'food': 'أكل',
    'transport': 'مواصلات',
    'health': 'علاج',
    'money': 'فلوس',
    'home': 'بيت',
    'fun': 'ترفيه',
    'work': 'شغل',
    'shopping': 'تسوق',
    'tech': 'تقنية',
    'other': 'أخرى',
  };

  static const categoryOrder = <String>[
    'all',
    'food',
    'transport',
    'health',
    'money',
    'home',
    'fun',
    'work',
    'shopping',
    'tech',
    'other',
  ];

  static final _baseIcons = <AppIconItem>[
    // food
    ..._iconsFor('food', [
      ('restaurant', 'وجبات', Icons.restaurant),
      ('local_pizza', 'بيتزا', Icons.local_pizza),
      ('coffee', 'قهوة', Icons.coffee),
      ('bakery', 'مخبوزات', Icons.bakery_dining),
      ('local_cafe', 'كافيه', Icons.local_cafe),
      ('icecream', 'حلويات', Icons.icecream),
      ('ramen', 'نودلز', Icons.ramen_dining),
      ('fastfood', 'وجبة سريعة', Icons.fastfood),
      ('breakfast', 'فطار', Icons.free_breakfast),
      ('egg', 'بيض', Icons.egg),
      ('cake', 'كيك', Icons.cake),
      ('lunch', 'غداء', Icons.lunch_dining),
      ('fa_utensils', 'أدوات طعام', FontAwesomeIcons.utensils),
      ('fa_burger', 'برجر', FontAwesomeIcons.burger),
      ('fa_pizza', 'بيتزا', FontAwesomeIcons.pizzaSlice),
      ('fa_apple', 'تفاح', FontAwesomeIcons.appleWhole),
      ('fa_carrot', 'خضار', FontAwesomeIcons.carrot),
      ('fa_mug', 'مشروب ساخن', FontAwesomeIcons.mugHot),
      ('fa_ice', 'آيس كريم', FontAwesomeIcons.iceCream),
      ('fa_pepper', 'بهارات', FontAwesomeIcons.pepperHot),
      ('restaurant_menu', 'منيو', Icons.restaurant_menu),
      ('food_bank', 'أكل البيت', Icons.food_bank),
      ('local_bar', 'مشروبات', Icons.local_bar),
      ('local_drink', 'عصير', Icons.local_drink),
      ('dinner_dining', 'عشاء', Icons.dinner_dining),
      ('takeout_dining', 'تيك اواي', Icons.takeout_dining),
      ('set_meal', 'وجبة كاملة', Icons.set_meal),
      ('liquor', 'مشروب', Icons.liquor),
      ('emoji_food', 'وجبات خفيفة', Icons.emoji_food_beverage),
      ('soup_kitchen', 'شوربة', Icons.soup_kitchen),
      ('fa_fish', 'سمك', FontAwesomeIcons.fish),
      ('fa_cheese', 'جبنة', FontAwesomeIcons.cheese),
      ('fa_lemon', 'ليمون', FontAwesomeIcons.lemon),
      ('fa_bacon', 'بيكون', FontAwesomeIcons.bacon),
      ('fa_bread', 'خبز', FontAwesomeIcons.breadSlice),
      ('fa_hotdog', 'هوت دوج', FontAwesomeIcons.hotdog),
      ('fa_shrimp', 'جمبري', FontAwesomeIcons.shrimp),
      ('fa_wheat', 'حبوب', FontAwesomeIcons.wheatAwn),
      ('fa_bottle', 'مياه', FontAwesomeIcons.bottleWater),
      ('fa_martini', 'كوكتيل', FontAwesomeIcons.martiniGlass),
    ]),
    // transport
    ..._iconsFor('transport', [
      ('car', 'سيارة', Icons.directions_car),
      ('bus', 'أوتوبيس', Icons.directions_bus),
      ('subway', 'مترو', Icons.directions_subway),
      ('train', 'قطار', Icons.train),
      ('flight', 'طيران', Icons.flight),
      ('bike', 'دراجة', Icons.directions_bike),
      ('taxi', 'تاكسي', Icons.local_taxi),
      ('walk', 'مشي', Icons.directions_walk),
      ('fuel', 'بنزين', Icons.local_gas_station),
      ('map', 'خرائط', Icons.map),
      ('traffic', 'مرور', Icons.traffic),
      ('ev', 'شحن', Icons.ev_station),
      ('fa_car', 'سيارة', FontAwesomeIcons.carSide),
      ('fa_bus', 'باص', FontAwesomeIcons.bus),
      ('fa_train', 'قطار', FontAwesomeIcons.train),
      ('fa_plane', 'طائرة', FontAwesomeIcons.plane),
      ('fa_ship', 'سفينة', FontAwesomeIcons.ship),
      ('fa_bike', 'عجلة', FontAwesomeIcons.bicycle),
      ('fa_motor', 'موتوسيكل', FontAwesomeIcons.motorcycle),
      ('fa_gas', 'بنزين', FontAwesomeIcons.gasPump),
      ('commute', 'تنقل', Icons.commute),
      ('car_rental', 'تأجير', Icons.car_rental),
      ('car_repair', 'صيانة', Icons.car_repair),
      ('airport_shuttle', 'شاتل', Icons.airport_shuttle),
      ('electric_bike', 'عجلة كهربا', Icons.electric_bike),
      ('electric_scooter', 'سكوتر', Icons.electric_scooter),
      ('moped', 'دراجة نارية', Icons.moped),
      ('tram', 'ترام', Icons.tram),
      ('railway', 'سكك حديد', Icons.railway_alert),
      ('local_shipping', 'شحن', Icons.local_shipping),
      ('fa_truck', 'شاحنة', FontAwesomeIcons.truck),
      ('fa_van', 'فان', FontAwesomeIcons.vanShuttle),
      ('fa_road', 'طريق', FontAwesomeIcons.road),
      ('fa_route', 'مسار', FontAwesomeIcons.route),
      ('fa_location', 'موقع', FontAwesomeIcons.locationDot),
      ('fa_map_pin', 'خريطة', FontAwesomeIcons.mapLocationDot),
      ('fa_jet', 'نفاثة', FontAwesomeIcons.jetFighter),
      ('fa_heli', 'هليكوبتر', FontAwesomeIcons.helicopter),
      ('fa_tram', 'ترام', FontAwesomeIcons.trainTram),
      ('fa_cable', 'تلفريك', FontAwesomeIcons.cableCar),
    ]),
    // health
    ..._iconsFor('health', [
      ('favorite', 'صحة', Icons.favorite),
      ('medication', 'دواء', Icons.medication),
      ('hospital', 'مستشفى', Icons.local_hospital),
      ('vaccines', 'تطعيم', Icons.vaccines),
      ('fitness', 'رياضة', Icons.fitness_center),
      ('spa', 'سبا', Icons.spa),
      ('healing', 'عناية', Icons.healing),
      ('monitor_heart', 'نبض', Icons.monitor_heart),
      ('emergency', 'طوارئ', Icons.emergency),
      ('psychology', 'دعم نفسي', Icons.psychology),
      ('bloodtype', 'تحاليل', Icons.bloodtype),
      ('health', 'رعاية', Icons.health_and_safety),
      ('fa_heart', 'نبض', FontAwesomeIcons.heartPulse),
      ('fa_pills', 'حبوب', FontAwesomeIcons.pills),
      ('fa_syringe', 'حقنة', FontAwesomeIcons.syringe),
      ('fa_stethoscope', 'سماعة طبيب', FontAwesomeIcons.stethoscope),
      ('fa_hospital', 'مستشفى', FontAwesomeIcons.hospital),
      ('fa_medkit', 'عدة إسعاف', FontAwesomeIcons.kitMedical),
      ('fa_tooth', 'أسنان', FontAwesomeIcons.tooth),
      ('fa_wheelchair', 'مساعدة', FontAwesomeIcons.wheelchair),
      ('medical_services', 'خدمات طبية', Icons.medical_services),
      ('medication_liquid', 'دواء سائل', Icons.medication_liquid),
      ('monitor_weight', 'وزن', Icons.monitor_weight),
      ('self_improvement', 'استرخاء', Icons.self_improvement),
      ('sanitizer', 'تعقيم', Icons.sanitizer),
      ('masks', 'كمامة', Icons.masks),
      ('sick', 'مرض', Icons.sick),
      ('coronavirus', 'فيروس', Icons.coronavirus),
      ('elderly', 'كبار السن', Icons.elderly),
      ('accessibility', 'احتياجات خاصة', Icons.accessibility_new),
      ('fa_capsules', 'كبسولات', FontAwesomeIcons.capsules),
      ('fa_brain', 'عقل', FontAwesomeIcons.brain),
      ('fa_dna', 'تحاليل', FontAwesomeIcons.dna),
      ('fa_eye', 'عيون', FontAwesomeIcons.eye),
      ('fa_bandaid', 'لاصق طبي', FontAwesomeIcons.bandage),
      ('fa_lungs', 'رئة', FontAwesomeIcons.lungs),
      ('fa_notes', 'ملاحظات طبية', FontAwesomeIcons.notesMedical),
      ('fa_user_doctor', 'طبيب', FontAwesomeIcons.userDoctor),
      ('fa_pump', 'مطهر', FontAwesomeIcons.pumpMedical),
      ('fa_skull', 'تشخيص', FontAwesomeIcons.skull),
    ]),
    // money
    ..._iconsFor('money', [
      ('wallet', 'محفظة', Icons.account_balance_wallet),
      ('card', 'بطاقة', Icons.credit_card),
      ('bank', 'بنك', Icons.account_balance),
      ('cash', 'نقدي', Icons.payments),
      ('receipt', 'فاتورة', Icons.receipt_long),
      ('savings', 'ادخار', Icons.savings),
      ('attach_money', 'دولار', Icons.attach_money),
      ('currency_exchange', 'تحويل', Icons.currency_exchange),
      ('price_check', 'سعر', Icons.price_check),
      ('paid', 'مدفوع', Icons.paid),
      ('account_balance_wallet', 'حساب', Icons.wallet),
      ('trending', 'استثمار', Icons.trending_up),
      ('fa_bill', 'فاتورة', FontAwesomeIcons.moneyBill),
      ('fa_bill_wave', 'دفع', FontAwesomeIcons.moneyBillWave),
      ('fa_credit', 'بطاقة', FontAwesomeIcons.creditCard),
      ('fa_bank', 'بنك', FontAwesomeIcons.buildingColumns),
      ('fa_coins', 'عملات', FontAwesomeIcons.coins),
      ('fa_wallet', 'محفظة', FontAwesomeIcons.wallet),
      ('fa_receipt', 'إيصال', FontAwesomeIcons.receipt),
      ('fa_chart', 'نمو', FontAwesomeIcons.chartLine),
      ('point_of_sale', 'نقطة بيع', Icons.point_of_sale),
      ('request_quote', 'عرض سعر', Icons.request_quote),
      ('price_change', 'تغيير سعر', Icons.price_change),
      ('monetization', 'أموال', Icons.monetization_on),
      ('pie_chart', 'نسبة', Icons.pie_chart),
      ('query_stats', 'إحصائيات', Icons.query_stats),
      (
        'account_balance_wallet_outlined',
        'حفظ فلوس',
        Icons.account_balance_wallet_outlined
      ),
      ('payments_outlined', 'دفعات', Icons.payments_outlined),
      ('wallet_giftcard', 'بطاقة هدايا', Icons.card_giftcard),
      ('receipt_long_2', 'فواتير', Icons.receipt_long),
      ('fa_piggy', 'حصالة', FontAwesomeIcons.piggyBank),
      ('fa_landmark', 'مؤسسة', FontAwesomeIcons.landmark),
      ('fa_hand_dollar', 'دخل', FontAwesomeIcons.handHoldingDollar),
      ('fa_sack', 'مبلغ', FontAwesomeIcons.sackDollar),
      ('fa_money_check', 'شيك', FontAwesomeIcons.moneyCheckDollar),
      ('fa_file_invoice', 'فاتورة ضريبية', FontAwesomeIcons.fileInvoiceDollar),
      ('fa_percent', 'نسبة', FontAwesomeIcons.percent),
      ('fa_chart_pie', 'مخطط', FontAwesomeIcons.chartPie),
      ('fa_scale', 'توازن', FontAwesomeIcons.scaleBalanced),
      ('fa_arrow_trend', 'اتجاه مالي', FontAwesomeIcons.arrowTrendUp),
    ]),
    // home
    ..._iconsFor('home', [
      ('home', 'منزل', Icons.home),
      ('bed', 'غرفة', Icons.bed),
      ('weekend', 'أثاث', Icons.weekend),
      ('kitchen', 'مطبخ', Icons.kitchen),
      ('shower', 'حمام', Icons.shower),
      ('light', 'إضاءة', Icons.lightbulb),
      ('cleaning', 'تنظيف', Icons.cleaning_services),
      ('chair', 'كرسي', Icons.chair),
      ('apartment', 'عمارة', Icons.apartment),
      ('key', 'مفتاح', Icons.key),
      ('roof', 'صيانة', Icons.home_repair_service),
      ('water', 'مياه', Icons.water_drop),
      ('fa_house', 'بيت', FontAwesomeIcons.house),
      ('fa_couch', 'كنبة', FontAwesomeIcons.couch),
      ('fa_bed', 'سرير', FontAwesomeIcons.bed),
      ('fa_bath', 'حمام', FontAwesomeIcons.bath),
      ('fa_door', 'باب', FontAwesomeIcons.doorOpen),
      ('fa_bulb', 'إضاءة', FontAwesomeIcons.lightbulb),
      ('fa_plug', 'كهرباء', FontAwesomeIcons.plug),
      ('fa_tv', 'تلفزيون', FontAwesomeIcons.tv),
      ('garage', 'جراج', Icons.garage),
      ('deck', 'بلكونة', Icons.deck),
      ('yard', 'حديقة البيت', Icons.yard),
      ('fence', 'سور', Icons.fence),
      ('window', 'شباك', Icons.window),
      ('table_restaurant', 'سفرة', Icons.table_restaurant),
      ('chair_outlined', 'كرسي', Icons.chair_outlined),
      ('bathroom', 'حمام', Icons.bathroom),
      ('bathtub', 'بانيو', Icons.bathtub),
      ('electric_bolt', 'كهرباء', Icons.electric_bolt),
      ('fa_house_user', 'أسرة', FontAwesomeIcons.houseUser),
      ('fa_house_laptop', 'بيت ذكي', FontAwesomeIcons.houseLaptop),
      ('fa_faucet', 'حنفية', FontAwesomeIcons.faucetDrip),
      ('fa_fan', 'مروحة', FontAwesomeIcons.fan),
      ('fa_sink', 'حوض', FontAwesomeIcons.sink),
      ('fa_toilet', 'تواليت', FontAwesomeIcons.toilet),
      ('fa_toolbox', 'صيانة', FontAwesomeIcons.toolbox),
      ('fa_screwdriver', 'عدة', FontAwesomeIcons.screwdriverWrench),
      ('fa_broom', 'مقشة', FontAwesomeIcons.broom),
      ('fa_pump_soap', 'صابون', FontAwesomeIcons.pumpSoap),
    ]),
    // fun
    ..._iconsFor('fun', [
      ('movie', 'فيلم', Icons.movie),
      ('music', 'موسيقى', Icons.music_note),
      ('sports_esports', 'جيمز', Icons.sports_esports),
      ('celebration', 'خروجات', Icons.celebration),
      ('beach', 'رحلة', Icons.beach_access),
      ('camera', 'تصوير', Icons.camera_alt),
      ('sports', 'رياضة', Icons.sports_soccer),
      ('park', 'حديقة', Icons.park),
      ('attractions', 'ملاهي', Icons.attractions),
      ('festival', 'حفلة', Icons.festival),
      ('theater', 'مسرح', Icons.theaters),
      ('palette', 'فن', Icons.palette),
      ('fa_game', 'جيمز', FontAwesomeIcons.gamepad),
      ('fa_music', 'موسيقى', FontAwesomeIcons.music),
      ('fa_camera', 'تصوير', FontAwesomeIcons.camera),
      ('fa_film', 'سينما', FontAwesomeIcons.film),
      ('fa_ticket', 'تذكرة', FontAwesomeIcons.ticket),
      ('fa_dice', 'ترفيه', FontAwesomeIcons.dice),
      ('fa_masks', 'مسرح', FontAwesomeIcons.masksTheater),
      ('fa_headphones', 'سماعات', FontAwesomeIcons.headphones),
      ('sports_basketball', 'سلة', Icons.sports_basketball),
      ('sports_tennis', 'تنس', Icons.sports_tennis),
      ('sports_volleyball', 'طايرة', Icons.sports_volleyball),
      ('sports_baseball', 'بيسبول', Icons.sports_baseball),
      ('sports_bar', 'مشروب', Icons.sports_bar),
      ('casino', 'كازينو', Icons.casino),
      ('theater_comedy', 'كوميديا', Icons.theater_comedy),
      ('piano', 'بيانو', Icons.piano),
      ('brush', 'رسم', Icons.brush),
      ('nightlife', 'سهر', Icons.nightlife),
      ('fa_futbol', 'كرة', FontAwesomeIcons.futbol),
      ('fa_basketball', 'سلة', FontAwesomeIcons.basketball),
      ('fa_table_tennis', 'بينج', FontAwesomeIcons.tableTennisPaddleBall),
      ('fa_volleyball', 'فولي', FontAwesomeIcons.volleyball),
      ('fa_chess', 'شطرنج', FontAwesomeIcons.chess),
      ('fa_guitar', 'جيتار', FontAwesomeIcons.guitar),
      ('fa_drum', 'درامز', FontAwesomeIcons.drum),
      ('fa_mountain', 'رحلات', FontAwesomeIcons.mountainSun),
      ('fa_person_hiking', 'هايكنج', FontAwesomeIcons.personHiking),
      ('fa_masks_2', 'عرض', FontAwesomeIcons.masksTheater),
    ]),
    // work
    ..._iconsFor('work', [
      ('work', 'شغل', Icons.work),
      ('business', 'شركة', Icons.business),
      ('meeting', 'اجتماع', Icons.groups),
      ('laptop', 'لاب توب', Icons.laptop),
      ('desk', 'مكتب', Icons.desk),
      ('assignment', 'تاسك', Icons.assignment),
      ('schedule', 'دوام', Icons.schedule),
      ('engineering', 'هندسة', Icons.engineering),
      ('support', 'خدمة', Icons.support_agent),
      ('design', 'تصميم', Icons.design_services),
      ('calculate', 'حسابات', Icons.calculate),
      ('checklist', 'قائمة', Icons.checklist),
      ('fa_briefcase', 'بريف كيس', FontAwesomeIcons.briefcase),
      ('fa_building', 'شركة', FontAwesomeIcons.building),
      ('fa_laptop', 'لاب', FontAwesomeIcons.laptopCode),
      ('fa_user_tie', 'إدارة', FontAwesomeIcons.userTie),
      ('fa_handshake', 'اتفاق', FontAwesomeIcons.handshake),
      ('fa_clipboard', 'متابعة', FontAwesomeIcons.clipboardCheck),
      ('fa_calc', 'محاسبة', FontAwesomeIcons.calculator),
      ('fa_chart_col', 'تقارير', FontAwesomeIcons.chartColumn),
      ('badge', 'هوية', Icons.badge),
      ('calendar_month', 'تقويم', Icons.calendar_month),
      ('co_present', 'عرض', Icons.co_present),
      ('analytics', 'تحليل', Icons.analytics),
      ('description', 'مستند', Icons.description),
      ('event_note', 'ملاحظات', Icons.event_note),
      ('fact_check', 'مراجعة', Icons.fact_check),
      ('feed', 'تغذية راجعة', Icons.feed),
      ('folder_copy', 'ملفات', Icons.folder_copy),
      ('manage_accounts', 'إدارة', Icons.manage_accounts),
      ('fa_user_group', 'فريق', FontAwesomeIcons.userGroup),
      ('fa_users_gear', 'موارد بشرية', FontAwesomeIcons.usersGear),
      ('fa_presentation', 'اجتماع', FontAwesomeIcons.personChalkboard),
      ('fa_clipboard_list', 'لستة مهام', FontAwesomeIcons.clipboardList),
      ('fa_business_time', 'وقت العمل', FontAwesomeIcons.businessTime),
      ('fa_file_lines', 'عقود', FontAwesomeIcons.fileLines),
      ('fa_envelope', 'إيميل', FontAwesomeIcons.envelope),
      ('fa_phone', 'اتصال', FontAwesomeIcons.phone),
      ('fa_stamp', 'اعتماد', FontAwesomeIcons.stamp),
      ('fa_chart_area', 'أداء', FontAwesomeIcons.chartArea),
    ]),
    // shopping
    ..._iconsFor('shopping', [
      ('shopping_cart', 'سلة', Icons.shopping_cart),
      ('store', 'متجر', Icons.store),
      ('shopping_bag', 'شنطة', Icons.shopping_bag),
      ('checkroom', 'ملابس', Icons.checkroom),
      ('diamond', 'اكسسوار', Icons.diamond),
      ('chair_alt', 'أثاث', Icons.chair_alt),
      ('toys', 'ألعاب', Icons.toys),
      ('watch', 'ساعة', Icons.watch),
      ('phone_iphone', 'موبايل', Icons.phone_iphone),
      ('redeem', 'هدايا', Icons.redeem),
      ('local_mall', 'مول', Icons.local_mall),
      ('sell', 'عروض', Icons.sell),
      ('fa_cart', 'سلة', FontAwesomeIcons.cartShopping),
      ('fa_bag', 'شنطة', FontAwesomeIcons.bagShopping),
      ('fa_store', 'متجر', FontAwesomeIcons.store),
      ('fa_gift', 'هدايا', FontAwesomeIcons.gift),
      ('fa_tags', 'خصم', FontAwesomeIcons.tags),
      ('fa_shirt', 'ملابس', FontAwesomeIcons.shirt),
      ('fa_gem', 'اكسسوار', FontAwesomeIcons.gem),
      ('fa_basket', 'مشتريات', FontAwesomeIcons.basketShopping),
      ('add_shopping_cart', 'إضافة للسلة', Icons.add_shopping_cart),
      ('local_offer', 'عرض', Icons.local_offer),
      ('loyalty', 'نقاط', Icons.loyalty),
      ('shopping_basket', 'سلة يد', Icons.shopping_basket),
      ('store_mall_directory', 'مول', Icons.store_mall_directory),
      ('local_grocery_store', 'بقالة', Icons.local_grocery_store),
      ('receipt', 'فاتورة', Icons.receipt),
      ('inventory_2', 'منتجات', Icons.inventory_2),
      ('styler', 'ستايل', Icons.style),
      ('sell_outlined', 'تخفيض', Icons.sell_outlined),
      ('fa_cart_plus', 'أضف شراء', FontAwesomeIcons.cartPlus),
      ('fa_cash_register', 'كاشير', FontAwesomeIcons.cashRegister),
      ('fa_bag_store', 'بوتيك', FontAwesomeIcons.shop),
      ('fa_store_slash', 'إغلاق متجر', FontAwesomeIcons.storeSlash),
      ('fa_socks', 'ملابس', FontAwesomeIcons.socks),
      ('fa_glasses', 'نظارات', FontAwesomeIcons.glasses),
      ('fa_ring', 'خواتم', FontAwesomeIcons.ring),
      ('fa_ticket_simple', 'كوبون', FontAwesomeIcons.ticketSimple),
      ('fa_shop_lock', 'شراء آمن', FontAwesomeIcons.shopLock),
      ('fa_barcode', 'باركود', FontAwesomeIcons.barcode),
    ]),
    // tech
    ..._iconsFor('tech', [
      ('smartphone', 'موبايل', Icons.smartphone),
      ('computer', 'كمبيوتر', Icons.computer),
      ('wifi', 'إنترنت', Icons.wifi),
      ('memory', 'تقنية', Icons.memory),
      ('devices', 'أجهزة', Icons.devices),
      ('cable', 'كابلات', Icons.cable),
      ('router', 'راوتر', Icons.router),
      ('headset', 'سماعة', Icons.headset),
      ('monitor', 'شاشة', Icons.monitor),
      ('keyboard', 'كيبورد', Icons.keyboard),
      ('mouse', 'ماوس', Icons.mouse),
      ('cloud', 'سحابة', Icons.cloud),
      ('fa_mobile', 'موبايل', FontAwesomeIcons.mobileScreenButton),
      ('fa_laptop_code', 'تطوير', FontAwesomeIcons.laptopCode),
      ('fa_wifi', 'واي فاي', FontAwesomeIcons.wifi),
      ('fa_chip', 'شريحة', FontAwesomeIcons.microchip),
      ('fa_server', 'سيرفر', FontAwesomeIcons.server),
      ('fa_keyboard', 'كيبورد', FontAwesomeIcons.keyboard),
      ('fa_mouse', 'ماوس', FontAwesomeIcons.computerMouse),
      ('fa_headset', 'هيدسيت', FontAwesomeIcons.headset),
      ('tablet', 'تابلت', Icons.tablet),
      ('smartwatch', 'ساعة ذكية', Icons.watch),
      ('desktop_windows', 'ديسكتوب', Icons.desktop_windows),
      ('developer_mode', 'تطوير', Icons.developer_mode),
      ('developer_board', 'لوحة', Icons.developer_board),
      ('dns', 'DNS', Icons.dns),
      ('code', 'كود', Icons.code),
      ('bug_report', 'أخطاء', Icons.bug_report),
      ('security', 'أمان', Icons.security),
      ('storage', 'تخزين', Icons.storage),
      ('fa_tablet', 'تابلت', FontAwesomeIcons.tabletScreenButton),
      ('fa_desktop', 'شاشة', FontAwesomeIcons.desktop),
      ('fa_code_branch', 'نسخ', FontAwesomeIcons.codeBranch),
      ('fa_terminal', 'طرفية', FontAwesomeIcons.terminal),
      ('fa_database', 'قاعدة بيانات', FontAwesomeIcons.database),
      ('fa_cloud', 'سحابة', FontAwesomeIcons.cloud),
      ('fa_usb', 'USB', FontAwesomeIcons.usb),
      ('fa_print', 'طباعة', FontAwesomeIcons.print),
      ('fa_satellite', 'اتصال', FontAwesomeIcons.satelliteDish),
      ('fa_robot', 'روبوت', FontAwesomeIcons.robot),
    ]),
    // other
    ..._iconsFor('other', [
      ('category', 'عام', Icons.category),
      ('star', 'مميز', Icons.star),
      ('bookmark', 'مرجع', Icons.bookmark),
      ('bolt', 'سريع', Icons.bolt),
      ('pets', 'حيوانات', Icons.pets),
      ('school', 'تعليم', Icons.school),
      ('child_care', 'أطفال', Icons.child_care),
      ('card_giftcard', 'هدية', Icons.card_giftcard),
      ('local_florist', 'زهور', Icons.local_florist),
      ('public', 'عام', Icons.public),
      ('event', 'مناسبة', Icons.event),
      ('more_horiz', 'أخرى', Icons.more_horiz),
      ('fa_star', 'نجمة', FontAwesomeIcons.star),
      ('fa_bookmark', 'علامة', FontAwesomeIcons.bookmark),
      ('fa_bell', 'تنبيه', FontAwesomeIcons.bell),
      ('fa_book', 'كتاب', FontAwesomeIcons.book),
      ('fa_paw', 'حيوانات', FontAwesomeIcons.paw),
      ('fa_tree', 'طبيعة', FontAwesomeIcons.tree),
      ('fa_globe', 'عالمي', FontAwesomeIcons.globe),
      ('fa_circle', 'عام', FontAwesomeIcons.circleDot),
      ('auto_awesome', 'مميز', Icons.auto_awesome),
      ('explore', 'استكشاف', Icons.explore),
      ('flag', 'علم', Icons.flag),
      ('forest', 'غابة', Icons.forest),
      ('rocket_launch', 'انطلاق', Icons.rocket_launch),
      ('volunteer', 'مساعدة', Icons.volunteer_activism),
      ('celeb_other', 'حدث', Icons.celebration),
      ('lightning', 'نشاط', Icons.flash_on),
      ('travel', 'رحلات', Icons.travel_explore),
      ('waves', 'بحر', Icons.waves),
      ('fa_flag', 'علم', FontAwesomeIcons.flag),
      ('fa_compass', 'اتجاه', FontAwesomeIcons.compass),
      ('fa_feather', 'خفيف', FontAwesomeIcons.feather),
      ('fa_seedling', 'نمو', FontAwesomeIcons.seedling),
      ('fa_fire', 'نشاط', FontAwesomeIcons.fire),
      ('fa_moon', 'ليل', FontAwesomeIcons.moon),
      ('fa_sun', 'نهار', FontAwesomeIcons.sun),
      ('fa_anchor', 'ثابت', FontAwesomeIcons.anchor),
      ('fa_paperclip', 'ملحق', FontAwesomeIcons.paperclip),
      ('fa_wand', 'سحري', FontAwesomeIcons.wandMagicSparkles),
    ]),
  ];

  static List<AppIconItem> _iconsFor(
    String categoryId,
    List<(String, String, dynamic)> data,
  ) {
    return data
        .map((e) => AppIconItem(
              name: e.$1,
              label: e.$2,
              categoryId: categoryId,
              icon: e.$3,
            ))
        .toList();
  }

  static List<AppIconItem> iconsForCategory(String categoryId) {
    if (categoryId == 'all') {
      return List<AppIconItem>.from(_baseIcons);
    }
    return _baseIcons.where((icon) => icon.categoryId == categoryId).toList();
  }

  static dynamic iconForName(String name) {
    for (final item in _baseIcons) {
      if (item.name == name) return item.icon;
    }
    for (final item in _baseIcons) {
      if (name.contains(item.name)) return item.icon;
    }
    const legacyMap = <String, dynamic>{
      'PiggyBank': Icons.savings,
      'Wallet2': Icons.account_balance_wallet,
      'UtensilsCrossed': Icons.restaurant,
      'BriefcaseBusiness': Icons.work,
      'HeartPulse': Icons.favorite,
      'ShoppingCart': Icons.shopping_cart,
      'CarFront': Icons.directions_car,
      'Home': Icons.home,
    };
    return legacyMap[name] ?? Icons.category;
  }

  static Widget iconWidgetForName(
    String name, {
    Color? color,
    double size = 24,
  }) {
    final icon = iconForName(name);
    final iconData = icon as dynamic;
    if (iconData.fontPackage == 'font_awesome_flutter') {
      return FaIcon(iconData, color: color, size: size);
    }
    return Icon(iconData, color: color, size: size);
  }

  static IconData iconDataForName(String name) {
    final icon = iconForName(name);
    // This method is kept for older call sites that still expect IconData.
    // If the icon is a FontAwesome one, callers should migrate to
    // `iconWidgetForName` to avoid runtime type issues.
    if (icon is IconData) return icon;
    return Icons.category;
  }

  static Future<IconPickerResult?> show(
    BuildContext context, {
    required String initialIconName,
    required String initialColorHex,
    String title = 'تخصيص الأيقونة',
    String? name,
  }) {
    return showDialog<IconPickerResult>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppIconPickerDialog(
          initialIconName: initialIconName,
          initialColorHex: initialColorHex,
          title: title,
          name: name,
        ),
      ),
    );
  }

  @override
  State<AppIconPickerDialog> createState() => _AppIconPickerDialogState();
}

class _AppIconPickerDialogState extends State<AppIconPickerDialog> {
  late String _selectedCategoryId;
  late String _selectedIconName;
  late Color _selectedColor;
  int _step = 0;
  bool _useCustomPicker = false;

  static const _presetHexColors = [
    // أحمر → وردي → بنفسجي
    '#FFCDD2',
    '#E57373',
    '#E53935',
    '#C62828',
    '#AD1457',
    '#D81B60',
    '#EC407A',
    '#F48FB1',
    '#CE93D8',
    '#AB47BC',
    '#8E24AA',
    '#6A1B9A',
    // بنفسجي غامق → أزرق
    '#5E35B1',
    '#7E57C2',
    '#B39DDB',
    '#9FA8DA',
    '#5C6BC0',
    '#3949AB',
    '#283593',
    '#1E88E5',
    '#42A5F5',
    '#90CAF9',
    '#039BE5',
    '#00ACC1',
    // تركواز → أخضر
    '#4DD0E1',
    '#26A69A',
    '#00897B',
    '#0F766E',
    '#165b47',
    '#2F6F5E',
    '#43A047',
    '#7CB342',
    '#9CCC65',
    '#C5E1A5',
    // أصفر → برتقالي → بني
    '#FFD54F',
    '#F9A825',
    '#FB8C00',
    '#F4511E',
    '#8D6E63',
    '#6D4C41',
    // رمادي محايد + بيج/أوف وايت يلائمان خلفية الصفحة
    '#37474F',
    '#546E7A',
    '#90A4AE',
    '#D7CCC8',
    '#F0E6D2', // بيج
    '#FAF6EC', // أوف وايت
    '#1A1A1A',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIconName = widget.initialIconName;
    _selectedColor = _hexToColor(widget.initialColorHex);
    _selectedCategoryId = 'all';
  }

  @override
  Widget build(BuildContext context) {
    final icons = AppIconPickerDialog.iconsForCategory(_selectedCategoryId);
    const contentHeight = 460.0;
    final dialogWidth =
        math.min(520.0, MediaQuery.of(context).size.width - 32.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: const Color(0xFFFFFBF1),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _selectedColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedColor.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: AppIconPickerDialog.iconWidgetForName(
                          _selectedIconName,
                          color: _selectedColor,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.name ?? widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Step Toggle ──
                _stepToggle(),
                const SizedBox(height: 16),

                // ── Content ──
                SizedBox(
                  height: contentHeight,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _step == 0
                        ? Column(
                            key: const ValueKey('step0'),
                            children: [
                              _categoryChips(),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: const Color(0xFFE0DED6)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: _iconGrid(icons),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('step1'),
                            children: [
                              _colorPickerToggle(),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: const Color(0xFFE0DED6)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: _colorStep(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Action Buttons ──
                Row(
                  children: [
                    // زرار الإلغاء (step 0) أو الرجوع (step 1)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _step == 0
                            ? () => Navigator.pop(context)
                            : () => setState(() => _step = 0),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: BorderSide(
                            color: _step == 0
                                ? const Color(0xFFE53935)
                                : const Color(0xFFCCCBC3),
                            width: 1.5,
                          ),
                          foregroundColor: _step == 0
                              ? const Color(0xFFE53935)
                              : const Color(0xFF555550),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _step == 0 ? 'إلغاء' : 'رجوع',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // زرار التالي (step 0) أو التأكيد (step 1)
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _step == 0
                            ? () => setState(() => _step = 1)
                            : () => Navigator.pop(
                                  context,
                                  IconPickerResult(
                                    iconName: _selectedIconName,
                                    colorHex: _colorToHex(_selectedColor),
                                  ),
                                ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: _selectedColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _step == 0 ? 'التالي' : 'تأكيد',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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
      ),
    );
  }

  Widget _stepToggle() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDE6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _stepTab(0, 'الأيقونة', Icons.grid_view_rounded),
          const SizedBox(width: 8),
          _stepTab(1, 'اللون', Icons.palette_outlined),
        ],
      ),
    );
  }

  Widget _stepTab(int step, String label, IconData icon) {
    final active = _step == step;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _step = step),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? _selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _selectedColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.white : const Color(0xFF888880),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : const Color(0xFF888880),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorPickerToggle() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDE6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _colorToggleTab(false, 'ألوان مقترحة', Icons.auto_awesome_rounded),
          const SizedBox(width: 8),
          _colorToggleTab(true, 'لون مخصص', Icons.colorize_rounded),
        ],
      ),
    );
  }

  Widget _colorToggleTab(bool custom, String label, IconData icon) {
    final active = _useCustomPicker == custom;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _useCustomPicker = custom),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? _selectedColor : const Color(0xFF888880)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.black : const Color(0xFF888880),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppIconPickerDialog.categoryOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final id = AppIconPickerDialog.categoryOrder[index];
          final label = AppIconPickerDialog.categoryLabels[id] ?? id;
          final selected = id == _selectedCategoryId;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryId = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? _selectedColor.withValues(alpha: 0.13)
                    : const Color(0xFFEEEDE6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? _selectedColor.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? _selectedColor : const Color(0xFF666660),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _iconGrid(List<AppIconItem> icons) {
    if (_selectedCategoryId == 'all') {
      return CustomScrollView(
        slivers: AppIconPickerDialog.categoryOrder
            .where((id) => id != 'all')
            .expand((categoryId) {
          final groupIcons = AppIconPickerDialog.iconsForCategory(categoryId);
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text(
                  AppIconPickerDialog.categoryLabels[categoryId] ?? categoryId,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _selectedColor,
                  ),
                ),
              ),
            ),
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _iconCell(groupIcons[index]),
                childCount: groupIcons.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
            ),
          ];
        }).toList(),
      );
    }
    return GridView.builder(
      itemCount: icons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) => _iconCell(icons[index]),
    );
  }

  Widget _iconCell(AppIconItem item) {
    final active = _selectedIconName == item.name;
    return GestureDetector(
      onTap: () => setState(() => _selectedIconName = item.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: active
              ? _selectedColor.withValues(alpha: 0.12)
              : const Color(0xFFF8F7F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? _selectedColor : const Color(0xFFE0DED6),
            width: active ? 2.5 : 1,
          ),
        ),
        child: Center(
          child: AppIconPickerDialog.iconWidgetForName(
            item.name,
            size: 26,
            color: active ? _selectedColor : const Color(0xFF999990),
          ),
        ),
      ),
    );
  }

  Widget _colorStep() {
    if (_useCustomPicker) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _ColorBoxPicker(
            color: _selectedColor,
            onChanged: (c) => setState(() => _selectedColor = c),
          ),
        ),
      );
    }

    final colorHex = _colorToHex(_selectedColor);
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _presetHexColors.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final hex = _presetHexColors[index];
        final color = _hexToColor(hex);
        final selected = colorHex.toLowerCase() == hex.toLowerCase();
        final isLight = color.computeLuminance() > 0.6;
        final markColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? markColor
                    : (isLight
                        ? const Color(0xFFDDD8CC)
                        : Colors.transparent),
                width: selected ? 3.5 : (isLight ? 1 : 0),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      const BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
            ),
            child: selected
                ? Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: markColor,
                      size: 22,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Color _hexToColor(String hex) {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  }

  String _colorToHex(Color color) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);
    return '#'
        '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
  }
}

// class _ColorWheel extends StatelessWidget {
//   const _ColorWheel({
//     required this.color,
//     required this.onChanged,
//   });

//   final Color color;
//   final ValueChanged<Color> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 190,
//       height: 190,
//       child: _ColorWheelGesture(
//         color: color,
//         onChanged: onChanged,
//       ),
//     );
//   }
// }

class _ColorWheelGesture extends StatefulWidget {
  const _ColorWheelGesture({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorWheelGesture> createState() => _ColorWheelGestureState();
}

class _ColorWheelGestureState extends State<_ColorWheelGesture> {
  void _update(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final vector = localPosition - center;
    final radius = size.shortestSide / 2;
    final distance = vector.distance.clamp(0, radius);
    final saturation = (distance / radius).clamp(0.0, 1.0);
    final hue =
        ((math.atan2(vector.dy, vector.dx) * 180 / math.pi) + 360) % 360;
    final color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor();
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(widget.color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final radius = size.shortestSide / 2;
        final angle = hsv.hue * math.pi / 180;
        final distance = hsv.saturation * radius;
        final center = Offset(size.width / 2, size.height / 2);
        final knob = Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        );
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _WheelPainter(),
              ),
              Positioned(
                left: knob.dx - 10,
                top: knob.dy - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      )
                    ],
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

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: List.generate(
          13,
          (index) =>
              HSVColor.fromAHSV(1, (index * 30).toDouble(), 1, 1).toColor(),
        ),
      ).createShader(rect);
    canvas.drawCircle(center, radius, sweep);

    final radial = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Colors.transparent],
        stops: [0, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, radial);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ColorBoxPicker extends StatefulWidget {
  const _ColorBoxPicker({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorBoxPicker> createState() => _ColorBoxPickerState();
}

class _ColorBoxPickerState extends State<_ColorBoxPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant _ColorBoxPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // لو اللون اتغيّر من بره (مثلاً اختيار لون جاهز) زامن الحالة الداخلية
    final current = _hsv.toColor();
    if (current.toARGB32() != widget.color.toARGB32()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _updateSatVal(Offset pos, Size size) {
    final x = (pos.dx / size.width).clamp(0.0, 1.0);
    final y = (pos.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _hsv = _hsv.withSaturation(x).withValue(1 - y);
    });
    widget.onChanged(_hsv.toColor());
  }

  void _updateHue(Offset pos, double width) {
    final x = (pos.dx / width).clamp(0.0, 1.0);
    setState(() {
      _hsv = _hsv.withHue(x * 360);
    });
    widget.onChanged(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final pureHueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final markerOnLight = _hsv.value > 0.6 && _hsv.saturation < 0.4;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── مربع التشبّع/الإضاءة لنفس درجة اللون (Hue) المختارة ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final markerX = _hsv.saturation * size.width;
                final markerY = (1 - _hsv.value) * size.height;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GestureDetector(
                    onPanDown: (d) => _updateSatVal(d.localPosition, size),
                    onPanUpdate: (d) => _updateSatVal(d.localPosition, size),
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: _SatValBoxPainter(hueColor: pureHueColor),
                        ),
                        Positioned(
                          left: markerX - 13,
                          top: markerY - 13,
                          child: IgnorePointer(
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hsv.toColor(),
                                border: Border.all(
                                  color: markerOnLight
                                      ? const Color(0xFF1A1A1A)
                                      : Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // ── شريط اختيار درجة اللون (Hue) ──
          SizedBox(
            height: 34,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final markerX = (_hsv.hue / 360) * width;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: GestureDetector(
                    onPanDown: (d) => _updateHue(d.localPosition, width),
                    onPanUpdate: (d) => _updateHue(d.localPosition, width),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: List.generate(
                                13,
                                (i) => HSVColor.fromAHSV(
                                        1, (i * 30).toDouble(), 1, 1)
                                    .toColor(),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (markerX - 16).clamp(0.0, width - 32),
                          child: IgnorePointer(
                            child: Container(
                              width: 32,
                              height: 34,
                              decoration: BoxDecoration(
                                color: pureHueColor,
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
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
}

class _SatValBoxPainter extends CustomPainter {
  _SatValBoxPainter({required this.hueColor});

  final Color hueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // التشبّع: من الأبيض (يسار) إلى لون الـ Hue الصافي (يمين)
    final satPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, hueColor],
      ).createShader(rect);
    canvas.drawRect(rect, satPaint);

    // الإضاءة: من شفاف (أعلى) إلى أسود (أسفل)
    final valPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRect(rect, valPaint);
  }

  @override
  bool shouldRepaint(covariant _SatValBoxPainter oldDelegate) =>
      oldDelegate.hueColor != hueColor;
}
