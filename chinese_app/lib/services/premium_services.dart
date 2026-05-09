import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  Future<bool> isUserPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_premium_unlocked') ?? false;
    } catch (e) {
      print("Prefs error: $e");
      return false;
    }
  }

  Future<bool> canUserScan() async {
    if (await isUserPremium()) return true;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    String lastDate = prefs.getString('scan_date') ?? "";
    int scanCount = prefs.getInt('scan_count') ?? 0;

    if (lastDate != today) {
      await prefs.setString('scan_date', today);
      await prefs.setInt('scan_count', 1);
      return true;
    } else {
      if (scanCount < 3) {
        await prefs.setInt('scan_count', scanCount + 1);
        return true;
      } else {
        return false;
      }
    }
  }

  void showPaywallDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text("Passez Premium"),
          ],
        ),
        content: Text(
            "La fonctionnalité '$featureName' est réservée aux abonnés Premium. Débloquez tout le potentiel de Chang Chang !"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Plus tard")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_premium_unlocked', true);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("S'abonner (Test)")),
        ],
      ),
    );
  }
}
