import SwiftUI

struct DebugToolsView: View {
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Restore Old UserDefaults") {
                restoreUserDefaultsFromPlist()
                showAlert = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Success"), message: Text("UserDefaults restored."), dismissButton: .default(Text("OK")))
        }
    }
    
    func restoreUserDefaultsFromPlist() {
        if let path = Bundle.main.path(forResource: "com.sixuanhan.japass.Japanese-Assistant", ofType: "plist"),
           let oldDefaults = NSDictionary(contentsOfFile: path) as? [String: Any] {
            
            for (key, value) in oldDefaults {
                UserDefaults.standard.set(value, forKey: key)
            }
            
            UserDefaults.standard.set(true, forKey: "didMigrateOldDefaults")
            UserDefaults.standard.synchronize()
            print("✅ UserDefaults restored!")
        } else {
            print("❌ Could not find or read the old .plist")
        }
    }
}
