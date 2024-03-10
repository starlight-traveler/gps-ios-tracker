import UIKit
import CoreBluetooth
import CoreLocation

var myPeripheral: CBPeripheral?
var myCharacteristic: CBCharacteristic?
var manager: CBCentralManager?

let serviceUUID = CBUUID(string: "ab0828b1-198e-4351-b779-901fa0e0371e")
let peripheralUUID = CBUUID(string: "24517CE4-2DC1-6489-39A4-672BBE4344DF")
let targetCharacteristicUUID = CBUUID(string: "4AC8A682-9736-4E5D-932B-E9B31405049C")
let readCharacteristicUUID = CBUUID(string: "9db335aa-0c19-4a29-93c9-2dabeb1dd044")

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var sendText1Button: UIButton!
    @IBOutlet weak var sendText2Button: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var coordinatesLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var locationManager: CLLocationManager!
    var userLat: CLLocationDegrees?
    var userLong: CLLocationDegrees?
    var userAltitude: CLLocationDistance?
    var userHeading: CLLocationDirection?
    
    var logoImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Bluetooth setup
        manager = CBCentralManager(delegate: self, queue: nil)
        updateUIForDisconnectedState()
        
        setupLogoImageView()
        
        // Location setup
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading() // Start receiving heading updates

        }
    }
    
    func setupLogoImageView() {
        
        // Set the image for the UIImageView
        imageView.image = UIImage(named: "NDRT_Logo_Shamrock_VF_V1_Invert")
        
        // Adjust the contentMode if needed, .scaleAspectFit is a common choice
        imageView.contentMode = .scaleAspectFit
        
        // Add the UIImageView as a subview to the ViewController's view
        view.addSubview(imageView)
    }
    
    // MARK: Location Manager Delegate Methods
       func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
           guard let userLocation: CLLocation = locations.first else { return }
           
           userLat = userLocation.coordinate.latitude
           userLong = userLocation.coordinate.longitude
           userAltitude = userLocation.altitude
           
           // Use your location data as needed
           print("Current location latitude is: \(userLat ?? 0)")
           print("Current location longitude is: \(userLong ?? 0)")
           
//           DispatchQueue.main.async {
//               self.coordinatesLabel.text = "Lat: \(self.userLat ?? 0)\nLong: \(self.userLong ?? 0)"
//           }
       }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        userHeading = newHeading.magneticHeading  // Get magnetic heading
        
        DispatchQueue.main.async {
            // Update your coordinatesLabel to include altitude and heading
            self.coordinatesLabel.text = """
            Lat: \(self.userLat ?? 0)
            Long: \(self.userLong ?? 0)
            Altitude: \(self.userAltitude ?? 0) meters
            Heading: \(self.userHeading ?? 0)°
            """
        }
    }
       
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Location Error: \(error)")
        }

    @IBAction func scanButtonTouched(_ sender: Any) {
        guard let central = manager, central.state == .poweredOn else {
            print("Bluetooth is not available.")
            return
        }

        central.stopScan()
        print("Scanning for peripherals...")
        central.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    @IBAction func sendText1Touched(_ sender: Any) {
        guard let peripheral = myPeripheral, let services = peripheral.services else {
            print("Peripheral or services not found.")
            return
        }
        
        for service in services {
            if let characteristic = service.characteristics?.first(where: { $0.uuid == readCharacteristicUUID }) {
                peripheral.readValue(for: characteristic)
                print("Reading value from characteristic: \(characteristic.uuid)")
            }
        }
    }
    
    @IBAction func sendText2Touched(_ sender: Any) {
        sendText(text: "Foobar")
    }
    
    @IBAction func disconnectTouched(_ sender: Any) {
        if let peripheral = myPeripheral {
            manager?.cancelPeripheralConnection(peripheral)
        }
    }
    
    func sendText(text: String) {
        guard let peripheral = myPeripheral, let characteristic = myCharacteristic else {
            print("Peripheral or characteristic not found.")
            return
        }

        if let data = text.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered \(peripheral.name ?? "Unknown")")

        // Optionally, you might still want to check advertisement data or other criteria before connecting
        myPeripheral = peripheral
        myPeripheral?.delegate = self
        central.connect(peripheral, options: nil)
        central.stopScan() // Stop scanning once you've initiated a connection to a device
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("Bluetooth is switched off")
        case .poweredOn:
            print("Bluetooth is switched on")
        case .unsupported:
            print("Bluetooth is not supported")
        default:
            print("Unknown state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([serviceUUID])
        
        DispatchQueue.main.async {
            self.updateUIForConnectedState()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("Failed to disconnect: \(error.localizedDescription)")
        } else {
            print("Disconnected from \(peripheral.name ?? "Unknown")")
        }
        
        myPeripheral = nil
        myCharacteristic = nil
        
        DispatchQueue.main.async {
            self.updateUIForDisconnectedState()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("No services found.")
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            print("No characteristics found in service \(service.uuid).")
            return
        }

        for characteristic in characteristics {
            print("Found characteristic: \(characteristic.uuid)")

            // Check if this is the characteristic you want to send data to
            if characteristic.uuid == targetCharacteristicUUID {
                myCharacteristic = characteristic
                print("Target characteristic for sending data found: \(characteristic.uuid)")
                break  // Now it's safe to break since we've found the right characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        if characteristic.uuid == readCharacteristicUUID {
            if let value = characteristic.value {
                let stringValue = String(data: value, encoding: .utf8) ?? "unknown"
                print("Read value: \(stringValue)")
            } else {
                print("No value received from characteristic \(characteristic.uuid)")
            }
        }
    }
    
    

    private func updateUIForConnectedState() {
        connectButton?.isEnabled = false
        disconnectButton?.isEnabled = true
        sendText1Button?.isHidden = false
        sendText2Button.isHidden = false
    }

    private func updateUIForDisconnectedState() {
        connectButton?.isEnabled = true
        disconnectButton?.isEnabled = false
        sendText1Button?.isHidden = true
        sendText2Button?.isHidden = true
    }
}
