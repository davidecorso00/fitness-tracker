import SwiftUI
import AVFoundation

// MARK: - Food Prefill

struct FoodPrefill {
    var name: String = ""
    var kcal: String = ""
    var protein: String = ""
    var carbs: String = ""
    var fat: String = ""
    var fiber: String = ""
    var sugar: String = ""
    var saturatedFat: String = ""
    var salt: String = ""
    var scanMessage: String = ""
}

// MARK: - OpenFoodFacts Service

enum OpenFoodFactsService {
    static func fetch(barcode: String) async -> FoodPrefill {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            return FoodPrefill(scanMessage: "Barcode non trovato nel database")
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int, status == 1,
                  let product = json["product"] as? [String: Any] else {
                return FoodPrefill(scanMessage: "Barcode non trovato nel database")
            }
            let nutriments = product["nutriments"] as? [String: Any] ?? [:]
            let rawName = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            func num(_ key: String) -> String {
                if let d = nutriments[key] as? Double, d > 0 { return String(format: "%g", d) }
                if let s = nutriments[key] as? String, let d = Double(s), d > 0 { return String(format: "%g", d) }
                return ""
            }

            return FoodPrefill(
                name: rawName,
                kcal: num("energy-kcal_100g"),
                protein: num("proteins_100g"),
                carbs: num("carbohydrates_100g"),
                fat: num("fat_100g"),
                fiber: num("fiber_100g"),
                sugar: num("sugars_100g"),
                saturatedFat: num("saturated-fat_100g"),
                salt: num("salt_100g"),
                scanMessage: rawName.isEmpty ? "Nome non disponibile nel database" : ""
            )
        } catch {
            let isNetwork = (error as NSError).domain == NSURLErrorDomain
            return FoodPrefill(scanMessage: isNetwork ? "Nessuna connessione internet" : "Barcode non trovato nel database")
        }
    }
}

// MARK: - Scanner View Controller

private class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndStart()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stopRunning()
    }

    private func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startCapture() } else { self?.showPermissionDenied() }
                }
            }
        default:
            showPermissionDenied()
        }
    }

    private func startCapture() {
        let s = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              s.canAddInput(input) else { return }
        s.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard s.canAddOutput(output) else { return }
        s.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]

        let preview = AVCaptureVideoPreviewLayer(session: s)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)

        self.session = s
        self.previewLayer = preview
        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
    }

    private func showPermissionDenied() {
        let label = UILabel()
        label.text = "Accesso alla fotocamera non autorizzato.\nAbilitalo in Impostazioni > Privacy > Fotocamera."
        label.textColor = .white.withAlphaComponent(0.7)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        hasScanned = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onScan?(value)
    }
}

// MARK: - UIViewControllerRepresentable

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// MARK: - Barcode Scanner Sheet

struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ScannerRepresentable { barcode in
                onScan(barcode)
                dismiss()
            }
            .ignoresSafeArea()

            // Dimmed overlay with cutout
            GeometryReader { geo in
                let frameW: CGFloat = 280
                let frameH: CGFloat = 160
                let frameX = (geo.size.width - frameW) / 2
                let frameY = (geo.size.height - frameH) / 2

                Path { p in
                    p.addRect(CGRect(origin: .zero, size: geo.size))
                    p.addRoundedRect(in: CGRect(x: frameX, y: frameY, width: frameW, height: frameH),
                                     cornerSize: CGSize(width: 14, height: 14))
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

                // Frame border
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .frame(width: frameW, height: frameH)
                    .offset(x: frameX, y: frameY)

                // Corner accents
                let accentLen: CGFloat = 22
                let lw: CGFloat = 3.5
                scanCornerPath(x: frameX, y: frameY, len: accentLen, dx: 1, dy: 1)
                    .stroke(Color.acc, lineWidth: lw)
                scanCornerPath(x: frameX + frameW, y: frameY, len: accentLen, dx: -1, dy: 1)
                    .stroke(Color.acc, lineWidth: lw)
                scanCornerPath(x: frameX, y: frameY + frameH, len: accentLen, dx: 1, dy: -1)
                    .stroke(Color.acc, lineWidth: lw)
                scanCornerPath(x: frameX + frameW, y: frameY + frameH, len: accentLen, dx: -1, dy: -1)
                    .stroke(Color.acc, lineWidth: lw)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.white.opacity(0.8), Color.white.opacity(0.15))
                    }
                    .padding(.top, 16).padding(.trailing, 20)
                }
                Spacer()
                Text("Inquadra il barcode del prodotto")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.bottom, 60)
            }
        }
        .background(Color.black)
    }

    private func scanCornerPath(x: CGFloat, y: CGFloat, len: CGFloat, dx: CGFloat, dy: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: x, y: y + dy * len))
            p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x + dx * len, y: y))
        }
    }
}
