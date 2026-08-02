import PhotosUI
import SwiftUI
import UIKit

struct TeamSettingsView:View {
 enum LogoMode:String,CaseIterable { case crop="Square crop",fit="Fit" }
 @State private var settings:TeamSettingsModel?;@State private var name="";@State private var subsEnabled=true;@State private var driversVoidSubs=true;@State private var subAmount:Decimal=0.5;@State private var pickerItem:PhotosPickerItem?;@State private var sourceImage:UIImage?;@State private var previewImage:UIImage?;@State private var logoMode:LogoMode = .crop;@State private var logoURL:URL?;@State private var isSaving=false;@State private var error:String?
 let load:() async throws->TeamSettingsModel;let upload:(Data) async throws->URL;let save:(TeamSettingsModel) async throws->Void
 var body:some View { Form { Section("Team") { TextField("Team name",text:$name) }
  Section("Subs") { Toggle("Charge match subs",isOn:$subsEnabled);Toggle("Away drivers do not pay subs",isOn:$driversVoidSubs).disabled(!subsEnabled);TextField("Subs amount",value:$subAmount,format:.number.precision(.fractionLength(2))).keyboardType(.decimalPad).disabled(!subsEnabled) }
  Section { if let previewImage { Image(uiImage:previewImage).resizable().scaledToFit().frame(maxHeight:180).frame(maxWidth:.infinity).accessibilityLabel("Selected team logo preview") } else if let logoURL { AsyncImage(url:logoURL){$0.resizable().scaledToFit()}placeholder:{ProgressView()}.frame(height:120) }
   Picker("Logo layout",selection:$logoMode){ForEach(LogoMode.allCases,id:\.self){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented)
   PhotosPicker(selection:$pickerItem,matching:.images){Label("Choose team logo",systemImage:"photo")}
   if logoURL != nil || previewImage != nil { Button("Remove logo",role:.destructive){sourceImage=nil;previewImage=nil;logoURL=nil} }
  } header:{Text("Logo")} footer:{Text("HEIC, HEIF and other Photos formats are converted to a metadata-free JPEG under 1 MB before upload.")}
  if let error { Label(error,systemImage:"exclamationmark.triangle").foregroundStyle(RooBinTheme.Colors.danger) }
 }.navigationTitle("Team settings").toolbar{ToolbarItem(placement:.confirmationAction){Button("Save"){performSave()}.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty||isSaving)}}.task{await initialise()}.onChange(of:pickerItem){_,item in Task{await loadImage(item)}}.onChange(of:logoMode){_,_ in renderPreview()} }
 private func initialise() async { do {let s=try await load();settings=s;name=s.name;subsEnabled=s.subsEnabled;driversVoidSubs=s.driversVoidSubs;subAmount=s.subAmount;logoURL=s.logoURL}catch let e as LocalizedError{self.error=e.errorDescription}catch{self.error=RooBinError.unexpected.localizedDescription} }
 @MainActor private func loadImage(_ item: PhotosPickerItem?) async {
  guard let item else { return }
  do {
   guard let data = try await item.loadTransferable(type: Data.self),
         let image = UIImage(data: data) else {
    throw RooBinError.validation(message: "That image could not be opened. Choose another photo.")
   }
   error = nil
   sourceImage = image
   renderPreview()
  } catch let caught as LocalizedError {
   error = caught.errorDescription ?? RooBinError.unexpected.localizedDescription
  } catch {
   self.error = "That image could not be opened. Choose another photo."
  }
 }
 private func renderPreview(){guard let sourceImage else{return};previewImage=Self.render(sourceImage,mode:logoMode)}
 private func performSave() {
  guard !isSaving else { return }
  let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
  let shouldUseSubs = subsEnabled
  let shouldVoidDriverSubs = subsEnabled && driversVoidSubs
  let amount = subAmount
  let selectedPreview = previewImage
  let existingURL = logoURL
  isSaving = true
  error = nil
  Task {
   defer { isSaving = false }
   do {
    var finalURL = existingURL
    if let selectedPreview {
     guard let data = Self.compressedJPEG(selectedPreview) else {
      throw RooBinError.validation(message: "The logo could not be processed.")
     }
     finalURL = try await upload(data)
    }
    let updated = TeamSettingsModel(
     name: cleanName,
     subsEnabled: shouldUseSubs,
     driversVoidSubs: shouldVoidDriverSubs,
     subAmount: amount,
     logoURL: finalURL
    )
    try await save(updated)
    logoURL = finalURL
    sourceImage = nil
    previewImage = nil
   } catch let caught as LocalizedError {
    self.error = caught.errorDescription
   } catch {
    self.error = RooBinError.unexpected.localizedDescription
   }
  }
 }
 static func render(_ image:UIImage,mode:LogoMode)->UIImage {let size=CGSize(width:512,height:512);return UIGraphicsImageRenderer(size:size).image{ctx in ctx.cgContext.setFillColor(UIColor.black.cgColor);ctx.cgContext.fill(CGRect(origin:.zero,size:size));let scale=mode == .crop ? max(size.width/image.size.width,size.height/image.size.height):min(size.width/image.size.width,size.height/image.size.height);let draw=CGSize(width:image.size.width*scale,height:image.size.height*scale);image.draw(in:CGRect(x:(size.width-draw.width)/2,y:(size.height-draw.height)/2,width:draw.width,height:draw.height))}}
 static func compressedJPEG(_ image:UIImage)->Data? {for q in stride(from:0.85,through:0.35,by:-0.1){if let d=image.jpegData(compressionQuality:q),d.count<=400_000{return d}};return nil}
}
