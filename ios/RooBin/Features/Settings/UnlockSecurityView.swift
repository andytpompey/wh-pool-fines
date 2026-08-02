import SwiftUI

struct UnlockSecurityView:View {
 @State private var current="";@State private var next="";@State private var confirmation="";@State private var email="";@State private var verificationCode="";@State private var codeSent=false;@State private var isWorking=false;@State private var message:String?;@State private var error:String?
 let change:(String,String)async throws->Void;let loadEmail:()async throws->String;let requestCode:(String)async throws->Void;let recover:(String,String)async throws->String
 var body:some View {
  Form {
   Section("Change code") {
    SecureField("Current code",text:$current).keyboardType(.numberPad).privacySensitive()
    SecureField("New 4–12 digit code",text:$next).keyboardType(.numberPad).privacySensitive()
    SecureField("Confirm new code",text:$confirmation).keyboardType(.numberPad).privacySensitive()
    Button("Change unlock code"){performChange()}.disabled(!valid||isWorking)
   }
   Section {
    if !email.isEmpty { Text("Verify your identity using \(email).").font(.callout).foregroundStyle(RooBinTheme.Colors.secondaryText) }
    Button(codeSent ? "Send a new verification code" : "Send verification code"){sendVerification()}.disabled(email.isEmpty||isWorking)
    if codeSent {
     TextField("Eight-digit verification code",text:$verificationCode).keyboardType(.numberPad).privacySensitive()
     Button("Recover unlock code"){performRecovery()}.disabled(verificationCode.count != 8||isWorking)
    }
   } header: { Text("Recover code") } footer: { Text("After verification, RooBin rotates the team code and emails the new code only to eligible team captains.") }
   if let message { Label(message,systemImage:"checkmark.circle").foregroundStyle(RooBinTheme.Colors.success) }
   if let error { Label(error,systemImage:"exclamationmark.triangle").foregroundStyle(RooBinTheme.Colors.danger) }
  }
  .navigationTitle("Unlock security")
  .task {
   do { email=try await loadEmail() }
   catch let caught as LocalizedError { error=caught.errorDescription }
   catch { self.error=RooBinError.unexpected.localizedDescription }
  }
 }
 private var valid:Bool{(4...12).contains(current.count)&&(4...12).contains(next.count)&&next==confirmation&&next.allSatisfy(\.isNumber)}
 private func performChange(){isWorking=true;error=nil;Task{defer{isWorking=false;current="";next="";confirmation=""};do{try await change(current,next);message="Unlock code changed."}catch let e as LocalizedError{error=e.errorDescription}catch{self.error=RooBinError.unexpected.localizedDescription}}}
 private func sendVerification(){isWorking=true;error=nil;message=nil;Task{defer{isWorking=false};do{try await requestCode(email);codeSent=true;message="Verification code sent."}catch let e as LocalizedError{error=e.errorDescription}catch{self.error=RooBinError.unexpected.localizedDescription}}}
 private func performRecovery(){isWorking=true;error=nil;message=nil;Task{defer{isWorking=false};do{message=try await recover(email,verificationCode);verificationCode="";codeSent=false}catch let e as LocalizedError{error=e.errorDescription}catch{self.error=RooBinError.unexpected.localizedDescription}}}
}
