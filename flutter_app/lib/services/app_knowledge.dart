import '../models/models.dart';

/// Curated knowledge about the EdgeSpace AI application.
///
/// This service gives the assistant a reliable offline help layer for
/// navigation and app usage. It is intentionally kept separate from sensor
/// analysis so questions such as "How do I create a room?" work even when the
/// backend/Gemini is offline and there is no telemetry yet.
class AppKnowledgeBase {
  String contextualize(
    String question,
    List<ChatMessage> conversation,
  ) {
    final q = _normalize(question);
    final shortFollowUp = q == 'και μετα' ||
        q == 'μετα' ||
        q == 'και τωρα' ||
        q == 'πως' ||
        q == 'τι κανω μετα' ||
        q == 'then' ||
        q == 'what next' ||
        q == 'and then' ||
        q == 'γιατι' ||
        q == 'πες το πιο απλα' ||
        q == 'explain simpler';

    if (!shortFollowUp) {
      return question;
    }

    for (final message in conversation.reversed) {
      if (message.fromUser && message.text.trim().isNotEmpty) {
        return '${message.text.trim()} ${question.trim()}';
      }
    }

    return question;
  }

  String? answer(
    String question, {
    required int buildingCount,
    required int roomCount,
    required int provisionedDeviceCount,
    required bool demoMode,
    required bool backendOnline,
    List<ChatMessage> conversation = const [],
  }) {
    final q = _normalize(question);
    final currentName = _extractUserName(question);
    final knownName = currentName ?? _knownUserName(conversation);

    // ============================================================
    // CONVERSATIONAL / PERSONALITY LAYER
    // ============================================================
    // These intents are handled locally so the assistant feels natural even
    // when Gemini or the EdgeSpace backend is offline. Keep the social
    // meaning of "Τι κάνεις;" separate from "Τι μπορείς να κάνεις;".

    // Remember a name the user explicitly gives during this chat.
    // Example: «Με λένε Μιχάλη, εσένα;»
    if (currentName != null) {
      final asksAssistantName = _hasAny(q, [
        'εσενα',
        'εσυ',
        'και σενα',
        'και εσενα',
        'esena',
        'esy',
        'esi',
        'your name',
        'what about you',
      ]);

      if (asksAssistantName) {
        return 'Χάρηκα, $currentName! Εμένα με λένε EdgeSpace AI Assistant. '
            'Είμαι ο ενσωματωμένος βοηθός του EdgeSpace AI και μπορώ να σε καθοδηγώ μέσα στην εφαρμογή ή να αναλύω τα δεδομένα των χώρων σου.';
      }

      return 'Χάρηκα, $currentName! Θα θυμάμαι το όνομά σου όσο συνεχίζεται αυτή η συζήτηση. '
          'Πες μου τι θέλεις να κάνουμε.';
    }

    if (_hasAny(q, [
      'πωσ με λενε',
      'ποιο ειναι το ονομα μου',
      'θυμασαι πωσ με λενε',
      'θυμασαι το ονομα μου',
      'pws me lene',
      'pos me lene',
      'do you remember my name',
      'what is my name',
    ])) {
      if (knownName != null) {
        return 'Σε λένε $knownName.';
      }
      return 'Δεν μου έχεις πει ακόμη το όνομά σου σε αυτή τη συζήτηση. Αν μου πεις «με λένε ...», θα το χρησιμοποιώ όσο μιλάμε.';
    }

    if (_equalsAny(q, [
      'μονο αυτο',
      'αυτο μονο',
      'μονο αυτα',
      'is that all',
      'only that',
      'mono auto',
    ])) {
      return 'Όχι. Μπορώ να σε βοηθήσω με πολύ περισσότερα: χρήση της εφαρμογής, Buildings και Rooms, ESP32-C3 και BLE provisioning, Devices, Analytics, Alerts, Settings, backend, καθώς και ανάλυση των αισθητήρων. '
          'Αν το Gemini backend είναι διαθέσιμο, μπορώ επίσης να απαντήσω και σε πιο γενικές ερωτήσεις.';
    }

    if (_equalsAny(q, [
      'ωραια',
      'τελεια',
      'οκ',
      'okay',
      'ok',
      'ενταξει',
      'μπραβο',
      'nice',
      'great',
      'wraia',
      'teleia',
    ])) {
      return 'Τέλεια. Πες μου τι θέλεις να κάνουμε μετά.';
    }

    if (_equalsAny(q, [
      'παμε',
      'λοιπον',
      'συνεχισε',
      'pame',
      'loipon',
      'continue',
    ])) {
      return 'Πάμε. Πες μου τι θέλεις να κάνουμε ή ποια λειτουργία θέλεις να σου εξηγήσω.';
    }

    if (_hasAny(q, [
      'εσενα',
      'και εσυ',
      'και εσενα',
      'esena',
      'kai esy',
      'kai esi',
      'what about you',
    ]) && q.split(' ').length <= 6) {
      return 'Εμένα με λένε EdgeSpace AI Assistant. Είμαι ο ενσωματωμένος AI βοηθός του EdgeSpace AI.';
    }

    if (_hasAny(q, [
      'τι μπορεισ να κανεισ',
      'τι μπορεις να κανεις',
      'what can you do',
      'what do you do in this app',
      'τι δυνατοτητεσ εχεισ',
      'ποιεσ ειναι οι δυνατοτητεσ σου',
      'ti mporeis na kaneis',
      'ti boreis na kaneis',
    ])) {
      return _capabilities(
        buildingCount: buildingCount,
        roomCount: roomCount,
        provisionedDeviceCount: provisionedDeviceCount,
        demoMode: demoMode,
        backendOnline: backendOnline,
      );
    }

    if (_hasAny(q, [
      'πωσ σε λενε',
      'ποιο ειναι το ονομα σου',
      'ποιοσ εισαι',
      'τι εισαι',
      'pws se lene',
      'pos se lene',
      'poios eisai',
      'ti eisai',
      'what is your name',
      'whats your name',
      'who are you',
      'εσενα πωσ σε λενε',
      'εσυ πωσ λεγεσαι',
      'και εσενα',
      'esena pos se lene',
      'esy pos se lene',
    ])) {
      return 'Με λένε EdgeSpace AI Assistant. Είμαι ο ενσωματωμένος AI βοηθός του EdgeSpace AI. '
          'Μπορώ να σε καθοδηγώ στη χρήση της εφαρμογής, να εξηγώ τις λειτουργίες της, '
          'να σε βοηθώ με Buildings, Rooms, ESP32-C3, Analytics και Settings και να αναλύω '
          'τις μετρήσεις των χώρων όταν υπάρχουν δεδομένα.';
    }

    if (_hasAny(q, [
      'ποιοσ σε εφτιαξε',
      'ποιοσ σε δημιουργησε',
      'ποιοσ σε κατασκευασε',
      'who made you',
      'who created you',
      'poios se eftiaxe',
    ])) {
      return 'Δημιουργήθηκα ως ο ενσωματωμένος AI βοηθός του project EdgeSpace AI, '
          'ώστε να λειτουργώ σαν οδηγός και copilot μέσα στην εφαρμογή.';
    }

    if (_hasAny(q, [
      'τι κανεισ',
      'πωσ εισαι',
      'τι νεα',
      'πωσ παει',
      'και εσυ',
      'ti kaneis',
      'pos eisai',
      'ti nea',
      'pos paei',
      'kai esy',
      'kai esi',
      'how are you',
      'how are u',
      'how is it going',
      'hows it going',
    ])) {
      return 'Καλά, ευχαριστώ! Είμαι εδώ και έτοιμος να σε βοηθήσω. Εσύ πώς είσαι;';
    }

    if (_equalsAny(q, [
      'καλα',
      'καλα ειμαι',
      'μια χαρα',
      'πολυ καλα',
      'μια χαρα ειμαι',
      'good',
      'im good',
      'i am good',
      'kala',
      'kala eimai',
      'mia xara',
    ])) {
      return 'Χαίρομαι! Πες μου τι θέλεις να κάνουμε ή τι θέλεις να μάθεις.';
    }

    if (_hasAny(q, [
      'ευχαριστω',
      'να σαι καλα',
      'να εισαι καλα',
      'thanks',
      'thank you',
      'thx',
      'euxaristo',
    ])) {
      return 'Παρακαλώ! Είμαι εδώ όποτε με χρειαστείς.';
    }

    if (_equalsAny(q, [
      'γεια',
      'γεια σου',
      'γεια χαρα',
      'καλημερα',
      'καλησπερα',
      'hello',
      'hi',
      'hey',
      'geia',
      'geia sou',
      'kalimera',
      'kalispera',
    ])) {
      return 'Γεια! Είμαι ο EdgeSpace AI Assistant. Πώς μπορώ να σε βοηθήσω;';
    }

    if (_hasAny(q, [
      'αντιο',
      'τα λεμε',
      'καλη συνεχεια',
      'bye',
      'goodbye',
      'see you',
      'ta leme',
    ])) {
      return 'Τα λέμε! Όποτε χρειαστείς βοήθεια με το EdgeSpace AI ή κάτι άλλο, είμαι εδώ.';
    }

    if (_equalsAny(q, [
      'βοηθησε με',
      'χρειαζομαι βοηθεια',
      'help me',
      'help',
      'voithise me',
      'xreiazomai voitheia',
    ])) {
      return 'Φυσικά. Πες μου με δικά σου λόγια τι θέλεις να κάνεις. Μπορώ να σε καθοδηγήσω '
          'βήμα-βήμα μέσα στην εφαρμογή ή να σε βοηθήσω να καταλάβεις τα δεδομένα ενός χώρου.';
    }

    final isRoom = _hasAny(q, [
      'δωματι',
      'room',
      'domat',
      'dwmat',
      'χωρ',
      'xwro',
      'xoro',
      'space',
    ]);
    final isBuilding = _hasAny(q, [
      'κτιρι',
      'building',
      'ktir',
    ]);
    final isDevice = _hasAny(q, [
      'device',
      'συσκευ',
      'esp32',
      'esp 32',
      'kit',
      'bluetooth',
      'ble',
    ]);
    final wantsCreate = _hasAny(q, [
      'φτιαξ',
      'δημιουργ',
      'προσθε',
      'καινουργ',
      'νεο',
      'new',
      'create',
      'add',
      'ftiax',
      'dimiourg',
      'prosthes',
    ]);
    final wantsEdit = _hasAny(q, [
      'αλλαξ',
      'επεξεργ',
      'μετονομα',
      'edit',
      'rename',
      'change',
      'allax',
    ]);
    final wantsDelete = _hasAny(q, [
      'διαγραφ',
      'σβησ',
      'delete',
      'remove',
      'diagraf',
      'svhs',
    ]);
    final wantsMove = _hasAny(q, [
      'μεταφερ',
      'μετακιν',
      'αλλο δωματι',
      'move',
      'assign',
      'metakin',
      'metafer',
    ]);

    if (_hasAny(q, [
      'βοηθεια εφαρμογ',
      'πωσ δουλευει η εφαρμογ',
      'app help',
      'οδηγιεσ εφαρμογ',
      'πως δουλευει το edgespace',
      'πωσ δουλευει το edgespace',
    ])) {
      return _capabilities(
        buildingCount: buildingCount,
        roomCount: roomCount,
        provisionedDeviceCount: provisionedDeviceCount,
        demoMode: demoMode,
        backendOnline: backendOnline,
      );
    }

    if (isRoom && wantsCreate) {
      final prerequisite = buildingCount == 0
          ? '\n\nΣημαντικό: αυτή τη στιγμή δεν υπάρχει κτίριο. Δημιούργησε πρώτα ένα από Spaces → + → Add building.'
          : '';
      return 'Για να δημιουργήσεις νέο δωμάτιο:\n'
          '1. Πήγαινε στο Spaces από την κάτω μπάρα.\n'
          '2. Πάτησε το + επάνω δεξιά.\n'
          '3. Επίλεξε Add room.\n'
          '4. Διάλεξε το Building στο οποίο ανήκει.\n'
          '5. Συμπλήρωσε Room name και Floor.\n'
          '6. Πάτησε Create.\n\n'
          'Το νέο δωμάτιο θα εμφανιστεί αρχικά ως Waiting for data μέχρι να συνδεθεί kit ή να υπάρχουν μετρήσεις.'
          '$prerequisite';
    }

    if (isRoom && wantsEdit) {
      return 'Για να επεξεργαστείς δωμάτιο: Spaces → Rooms → ⋮ στο δωμάτιο → Edit room. '
          'Μπορείς να αλλάξεις Building, όνομα και όροφο και μετά να πατήσεις Save.';
    }

    if (isRoom && wantsDelete) {
      return 'Για διαγραφή δωματίου: Spaces → Rooms → ⋮ → Delete room και επιβεβαίωσε. '
          'Η εφαρμογή αφαιρεί και το assigned device/telemetry που συνδέεται με αυτό το δωμάτιο, οπότε έλεγξε πρώτα ότι πράγματι θέλεις να το διαγράψεις.';
    }

    if (isRoom && _hasAny(q, ['ανοιξ', 'λεπτομερ', 'details', 'detail', 'view', 'βλεπω'])) {
      return 'Για να δεις όλες τις πληροφορίες ενός δωματίου: Spaces → Rooms → πάτησε την κάρτα του δωματίου. '
          'Στο Room Detail βλέπεις environmental score, latest activity, γραφήματα, sensor health, στοιχεία device και AI insights.';
    }

    if (isBuilding && wantsCreate) {
      return 'Για νέο κτίριο: Spaces → + → Add building. Συμπλήρωσε Building name και προαιρετικά Location, μετά πάτησε Create. '
          'Μόλις υπάρχει κτίριο μπορείς να προσθέσεις δωμάτια σε αυτό.';
    }

    if (isBuilding && wantsEdit) {
      return 'Για αλλαγή κτιρίου: Spaces → Buildings → ⋮ → Edit building. Άλλαξε όνομα ή Location και πάτησε Save.';
    }

    if (isBuilding && wantsDelete) {
      return 'Για διαγραφή κτιρίου: Spaces → Buildings → ⋮ → Delete building. '
          'Προσοχή: μαζί διαγράφονται τα δωμάτια του κτιρίου και τα σχετικά assigned devices/telemetry.';
    }

    if (isDevice && wantsCreate) {
      if (roomCount == 0) {
        return 'Πριν συνδέσεις ESP32-C3 πρέπει να υπάρχει τουλάχιστον ένα δωμάτιο. '
            'Δημιούργησε πρώτα Spaces → + → Add room και μετά πήγαινε Settings → Device Manager → +.';
      }
      return 'Για να προσθέσεις ESP32-C3 kit:\n'
          '1. Άνοιξε Settings → Device Manager και πάτησε + (ή Spaces → + → Connect ESP32-C3 kit).\n'
          '2. Πάτησε Scan Bluetooth.\n'
          '3. Επίλεξε το EdgeSpace/ESP32-C3 που βρέθηκε.\n'
          '4. Πάτησε Continue to Configuration.\n'
          '5. Δώσε Device name, επίλεξε Room και βάλε Wi-Fi SSID/Password.\n'
          '6. Έλεγξε το EdgeSpace Server και στείλε το provisioning.\n\n'
          'Σε πραγματικό κινητό/ESP32 ο server πρέπει να είναι LAN διεύθυνση του υπολογιστή, π.χ. http://192.168.1.100:8000, όχι 10.0.2.2.';
    }

    if (isDevice && wantsEdit && _hasAny(q, ['ονομα', 'name', 'rename', 'μετονομα'])) {
      return 'Για μετονομασία device: Settings → Device Manager → ⋮ στο kit → Rename. Γράψε το νέο όνομα και πάτησε Save.';
    }

    if (isDevice && wantsMove) {
      return 'Για να μεταφέρεις ένα ESP32-C3 σε άλλο δωμάτιο: Settings → Device Manager → ⋮ → Move to room. '
          'Επίλεξε διαθέσιμο Room και πάτησε Move. Ένα Room μπορεί να έχει ένα assigned kit στο τρέχον prototype.';
    }

    if (isDevice && wantsDelete) {
      return 'Για διαγραφή device: Settings → Device Manager → ⋮ → Delete device. '
          'Μετά τη διαγραφή το Room μένει στην εφαρμογή αλλά γίνεται unassigned ώστε να μπορείς να συνδέσεις άλλο kit.';
    }

    if (isDevice && _hasAny(q, ['offline', 'αποσυνδε', 'disconnect'])) {
      return 'Από Settings → Device Manager → ⋮ μπορείς να επιλέξεις Mark offline. '
          'Στο real mode η εφαρμογή επίσης θεωρεί μια provisioned συσκευή offline όταν δεν λαμβάνει νέα δεδομένα για αρκετό χρόνο.';
    }

    if (isDevice && _hasAny(q, ['restart', 'επανεκκιν', 'reconfigure', 'wifi', 'wi-fi'])) {
      return 'Στο Room Detail εμφανίζονται τα κουμπιά Restart Device και Reconfigure Wi-Fi, αλλά στο τρέχον conference prototype δεν υπάρχει ακόμη ολοκληρωμένο BLE/backend command που να εκτελεί αυτές τις δύο ενέργειες end-to-end. '
          'Για νέο provisioning χρησιμοποίησε προς το παρόν Device Manager → + Add ESP32-C3.';
    }


    if (isDevice && _hasAny(q, ['που βλεπω', 'που ειναι', 'λιστα', 'manager', 'details', 'λεπτομερ'])) {
      return 'Για να δεις τις συσκευές: Settings → Device Manager. Εκεί βλέπεις όλα τα provisioned ESP32-C3 kits, status, assigned Room, RSSI, firmware και last seen. Πάτησε μια συσκευή ή το ⋮ για τις διαθέσιμες ενέργειες.';
    }

    if (_hasAny(q, ['φιλτρ', 'filter'])) {
      return 'Υπάρχουν φίλτρα σε δύο βασικά σημεία: στο Spaces μπορείς να φιλτράρεις rooms ανά status (Healthy / Needs attention / Critical / Waiting for data), ενώ στο Analytics μπορείς να αλλάξεις Parameter, Aggregation, Time Range, Building και Room.';
    }

    if (_hasAny(q, ['settings', 'ρυθμισ', 'ρυθμισεισ'])) {
      return 'Οι βασικές ρυθμίσεις είναι στο tab Settings. Εκεί βρίσκεις Device Manager, Connect New Kit, Backend URL, Demo data mode και Gemini AI Advisor.';
    }

    if (_hasAny(q, ['analytics', 'αναλυτικ', 'γραφημ', 'chart', 'μετρικ', 'στατιστικ'])) {
      return 'Στο Analytics μπορείς να αλλάξεις Parameter, Aggregation, Time Range, Building και Room filter. '
          'Βλέπεις cross-space snapshot, room ranking και automatic insights. Το Copy CSV αντιγράφει τα δεδομένα, ενώ ο πραγματικός file/PDF exporter δεν έχει ακόμη συνδεθεί στο prototype.';
    }

    if (_hasAny(q, ['alert', 'ειδοποι', 'συναγερ', 'acknowledge'])) {
      return 'Τα alerts ανοίγουν από το εικονίδιο ειδοποιήσεων στο Dashboard. '
          'Μπορείς να φιλτράρεις All / Open / Critical και να πατήσεις Acknowledge. '
          'Στο τρέχον prototype τα demo alerts λειτουργούν, αλλά οι πλήρεις backend alert rules δεν έχουν ακόμη συνδεθεί.';
    }

    if (_hasAny(q, ['demo mode', 'demo data', 'demo', 'εικονικ δεδομεν', 'δοκιμαστικ δεδομεν'])) {
      return 'Το Demo data mode βρίσκεται στο Settings → Data & AI. '
          'Όταν είναι ενεργό, η εφαρμογή δημιουργεί δοκιμαστικές μετρήσεις ώστε να μπορείς να παρουσιάσεις Dashboard/Analytics χωρίς πραγματικό backend. '
          'Όταν το κλείσεις, η εφαρμογή περιμένει πραγματικά telemetry δεδομένα από τον EdgeSpace backend.';
    }

    if (_hasAny(q, ['backend', 'server url', '10.0.2.2', '192.168', 'server'])) {
      return 'Το Backend URL αλλάζει από Settings → Data & AI → Backend URL → Save Settings. '
          '10.0.2.2 χρησιμοποιείται μόνο από Android Emulator για να φτάσει τον υπολογιστή. '
          'Σε πραγματικό Samsung και ESP32-C3 βάλε την τοπική IPv4 του υπολογιστή στο ίδιο Wi-Fi, π.χ. http://192.168.1.100:8000.';
    }

    if (_hasAny(q, ['gemini', 'ai advisor', 'ai assistant', 'τεχνητη νοημοσυνη'])) {
      return 'Ο AI Assistant ανοίγει από το tab AI. Μπορείς να επιλέξεις All spaces ή συγκεκριμένο Room και να γράψεις ελεύθερα την ερώτησή σου. '
          'Για ερωτήσεις χρήσης της εφαρμογής έχω offline App Guide. Για πιο ελεύθερες/γενικές απαντήσεις και βαθύτερη ανάλυση χρησιμοποιείται Gemini όταν το Gemini AI Advisor είναι ενεργό και ο backend είναι online.';
    }

    if (_hasAny(q, ['qr', 'qr code', 'κωδικ'])) {
      return 'Κατά την προσθήκη ESP32-C3 μπορείς να πατήσεις Scan Kit QR Code. '
          'Η τιμή του QR χρησιμοποιείται ως Device ID όταν ολοκληρωθεί το provisioning.';
    }

    if (_hasAny(q, ['waiting for data', 'χωρισ δεδομεν', 'δεν εχει δεδομεν', '0 βαθμου', 'critical χωρις'])) {
      return 'Το Waiting for data σημαίνει ότι δεν υπάρχει ακόμη telemetry για το συγκεκριμένο Room. '
          'Η εφαρμογή δεν πρέπει να το θεωρεί Critical μόνο και μόνο επειδή λείπουν μετρήσεις. Μόλις φτάσει το πρώτο sensor packet θα εμφανιστούν πραγματικές τιμές και environmental score.';
    }

    if (_hasAny(q, ['energy', 'ενεργει', 'kwh', 'ρευμ', 'power'])) {
      return 'Το Energy Monitoring είναι στο roadmap του EdgeSpace AI, αλλά δεν έχει ακόμη συνδεθεί end-to-end με ενεργό telemetry/UI/backend στο τρέχον conference prototype. '
          'Άρα δεν θα σου εμφανίσω ψεύτικα W/kWh μέχρι να συνδέσουμε πραγματικό energy sensor ή backend feed.';
    }

    if (_hasAny(q, ['login', 'google sign', 'google login', 'συνδεση google'])) {
      return 'Το Google Sign-In είναι ακόμη σε development κατάσταση λόγω του Android/Google re-auth issue που εμφανίστηκε στις δοκιμές. '
          'Για να μη μπλοκάρει η ανάπτυξη, το prototype χρησιμοποιεί προσωρινό development bypass μέχρι να κλείσουμε οριστικά το authentication flow.';
    }

    if (_hasAny(q, ['home', 'dashboard', 'αρχικη'])) {
      return 'Στο Dashboard βλέπεις Buildings, Rooms, Online Devices, Alerts, Environmental Health, priority rooms και πρόσφατα events. '
          'Από επάνω μπορείς επίσης να ανοίξεις Alerts ή να ξεκινήσεις προσθήκη device.';
    }

    if (_hasAny(q, ['spaces', 'χωροι', 'χωροσ', 'χώροι', 'τι ειναι room', 'τι ειναι building'])) {
      return 'Το Spaces οργανώνει τη φυσική δομή της εγκατάστασης: Building → Rooms → assigned ESP32-C3 kit. '
          'Από εκεί δημιουργείς/επεξεργάζεσαι/διαγράφεις Buildings και Rooms και ανοίγεις το Room Detail.';
    }

    return null;
  }

  String buildRemoteContext({
    required String stateSummary,
  }) {
    return '''
You are EdgeSpace AI Assistant, the in-app copilot of the EdgeSpace AI conference prototype.

PERSONALITY & CONVERSATION
- Your name is EdgeSpace AI Assistant.
- Speak naturally, warmly and clearly. Do not sound like a menu of predefined commands.
- Understand normal small talk such as greetings, "How are you?", thanks and short follow-ups.
- Treat "Τι κάνεις;" as social conversation, but treat "Τι μπορείς να κάνεις;" as a capabilities question.
- Preserve conversation context so follow-ups like "και μετά;", "γιατί;" or "πες το πιο απλά" refer to the previous exchange.
- Do not claim human experiences, physical actions or feelings as facts. A friendly conversational tone is fine.
- If the user asks your identity, say you are the in-app AI assistant of EdgeSpace AI.

PRIMARY ROLE
- Help the user operate the EdgeSpace AI mobile application using natural language.
- Analyze smart-space telemetry when data is available.
- Answer general questions when appropriate, but keep the conversation useful and gently relate prolonged off-topic discussion back to the app when relevant.
- If the user writes Greek or Greeklish, answer in Greek unless they ask for another language.
- Be concise but give exact navigation paths and practical next steps.
- Never invent a feature that the current prototype does not implement.

APPLICATION MAP
1. Home / Dashboard
   - KPIs: Buildings, Rooms, Online Devices, Alerts.
   - Environmental Health, priority rooms, latest events.
   - Top actions include Add Device and Alerts.
2. Spaces
   - Tabs: Buildings and Rooms.
   - + menu: Add building, Add room, Connect ESP32-C3 kit.
   - Building actions: Edit, Delete.
   - Room actions: Edit, Delete; tap room card for Room Detail.
   - New rooms without telemetry show Waiting for data.
3. Room Detail
   - Environmental Score, latest activity, charts, AI insights, Sensor Health, Device information.
   - "Ask AI about this room" opens AI scoped to that room.
   - Restart Device and Reconfigure Wi-Fi are visible prototype controls but do not yet have a complete end-to-end command implementation.
4. Device Manager
   - Open from Settings → Device Manager.
   - Add ESP32-C3, search/filter devices, view details.
   - Device actions: Rename, Move to room, Mark offline, Delete.
   - Provisioning flow: BLE scan → select kit → configuration → device name + room + Wi-Fi + backend URL → provision.
   - QR code may be used as Device ID.
5. Analytics
   - Parameter, Aggregation, Time Range, Building and Room filters.
   - Cross-space snapshot, room ranking, automatic insights.
   - Copy CSV works. Detailed PDF/file export is not wired yet.
6. Alerts
   - All / Open / Critical filters and Acknowledge.
   - Demo alerts exist; full backend alert-rule automation is not yet wired.
7. AI Assistant
   - Scope can be All spaces or one Room.
   - App-help questions must work even without telemetry.
   - Gemini is routed through the EdgeSpace backend when enabled/online; local fallback handles app guidance and deterministic sensor analysis.
8. Settings
   - Device Manager and Connect New Kit.
   - Backend URL, Demo data mode, Gemini AI Advisor.
   - On Android Emulator, 10.0.2.2 reaches the host computer.
   - On a physical phone/ESP32 use the computer's LAN IPv4 on the same Wi-Fi, e.g. http://192.168.1.100:8000.

KNOWN PROTOTYPE LIMITS
- Google Sign-In is temporarily bypassed during development because of the Google/Android re-auth issue encountered in testing.
- Backend server is required for real telemetry and remote Gemini.
- Energy Monitoring is planned but not yet connected end-to-end.
- Restart Device / Reconfigure Wi-Fi are not yet backed by a complete command protocol.
- Detailed PDF/file report export is not wired yet.
- Custom analytics range currently behaves as a 7-day window.

CURRENT APPLICATION STATE
$stateSummary

When the user asks how to do something, give the exact path first, then the steps. When the user asks about sensor conditions, use only the supplied current state/telemetry and clearly say when data is missing.
''';
  }

  String? _knownUserName(List<ChatMessage> conversation) {
    for (final message in conversation.reversed) {
      if (!message.fromUser) {
        continue;
      }
      final name = _extractUserName(message.text);
      if (name != null) {
        return name;
      }
    }
    return null;
  }

  String? _extractUserName(String input) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:με\s+λένε|με\s+λενε|ονομάζομαι|ονομαζομαι)\s+([A-Za-zΑ-Ωα-ωΆ-ώϊϋΐΰ]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:my\s+name\s+is)\s+([A-Za-z]+)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input.trim());
      final raw = match?.group(1)?.trim();
      if (raw == null || raw.isEmpty) {
        continue;
      }
      return _capitalizeName(raw);
    }

    return null;
  }

  String _capitalizeName(String value) {
    if (value.isEmpty) {
      return value;
    }
    if (value.length == 1) {
      return value.toUpperCase();
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _capabilities({
    required int buildingCount,
    required int roomCount,
    required int provisionedDeviceCount,
    required bool demoMode,
    required bool backendOnline,
  }) {
    final mode = demoMode ? 'Demo data mode' : 'Real data mode';
    final backend = backendOnline ? 'online' : 'offline';

    return 'Μπορώ να σε βοηθήσω σαν οδηγός ολόκληρου του EdgeSpace AI, όχι μόνο με έτοιμες εντολές. '
        'Μπορείς να με ρωτήσεις π.χ. «πώς φτιάχνω νέο δωμάτιο;», «πώς μεταφέρω ένα ESP32 σε άλλο room;», «πού αλλάζω το backend;», «τι σημαίνει Waiting for data;» ή να μου ζητήσεις ανάλυση αισθητήρων.\n\n'
        'Αυτή τη στιγμή η εφαρμογή έχει $buildingCount building(s), $roomCount room(s) και $provisionedDeviceCount provisioned kit(s). '
        'Mode: $mode · Backend: $backend.\n\n'
        'Για ερωτήσεις που ξεφεύγουν από την εφαρμογή, το Gemini μπορεί να απαντήσει πιο γενικά όταν ο backend είναι διαθέσιμος.';
  }

  bool _equalsAny(String value, List<String> terms) {
    return terms.contains(value);
  }

  bool _hasAny(String value, List<String> terms) {
    return terms.any(value.contains);
  }

  String _normalize(String input) {
    var out = input.toLowerCase().trim();

    const replacements = {
      'ά': 'α',
      'έ': 'ε',
      'ή': 'η',
      'ί': 'ι',
      'ϊ': 'ι',
      'ΐ': 'ι',
      'ό': 'ο',
      'ύ': 'υ',
      'ϋ': 'υ',
      'ΰ': 'υ',
      'ώ': 'ω',
      'ς': 'σ',
    };

    for (final entry in replacements.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }

    out = out.replaceAll(RegExp(r'[^a-z0-9α-ω.:/ -]+'), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }
}
