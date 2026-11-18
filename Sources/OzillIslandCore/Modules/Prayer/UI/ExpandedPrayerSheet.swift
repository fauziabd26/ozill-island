import SwiftUI

public struct ExpandedPrayerSheet: View {
    @ObservedObject var vm: PrayerIslandViewModel
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header: Location & Action buttons
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)
                    Text(vm.locationManager.locationName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Button(action: {
                        vm.locationManager.requestSingleLocation()
                    }) {
                        Image(systemName: vm.locationManager.isLocating ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .rotationEffect(.degrees(vm.locationManager.isLocating ? 360 : 0))
                            .animation(vm.locationManager.isLocating ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.locationManager.isLocating)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh Lokasi GPS")
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        vm.openSettings()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Pengaturan & Koreksi Waktu")
                    
                    Button(action: {
                        vm.collapse()
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Tutup Island")
                }
            }
            
            // Audio alert bar if playing
            if vm.audioManager.isPlaying {
                HStack {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.green)
                    Text("Adzan \(vm.audioManager.currentPrayerName) sedang berkumandang")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Hentikan") {
                        vm.audioManager.stop()
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
            }
            
            // Hero: Next Prayer Card
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.orange.opacity(0.8), .yellow.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)
                        Image(systemName: vm.scheduler.nextPrayerName.sfSymbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MENUJU WAKTU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        Text(vm.scheduler.nextPrayerName.rawValue)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let schedule = vm.scheduler.schedule {
                        Text(schedule.formattedTime(for: vm.scheduler.nextPrayerName, timeZone: vm.locationManager.currentTimeZone))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Text(vm.scheduler.timeRemainingString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            
            // Full Prayer List (6 times including Syuruq)
            if let schedule = vm.scheduler.schedule {
                let now = Date()
                let next = vm.scheduler.nextPrayerName
                
                VStack(spacing: 4) {
                    ForEach(schedule.items, id: \.prayer.rawValue) { item in
                        let isNext = item.prayer == next
                        let isPassed = item.time < now && !isNext
                        
                        HStack {
                            Image(systemName: item.prayer.sfSymbol)
                                .font(.system(size: 11))
                                .foregroundColor(isNext ? .orange : (isPassed ? .gray : .white.opacity(0.8)))
                                .frame(width: 16)
                            
                            Text(item.prayer.rawValue)
                                .font(.system(size: 12, weight: isNext ? .bold : .regular))
                                .foregroundColor(isNext ? .white : (isPassed ? .white.opacity(0.4) : .white.opacity(0.85)))
                            
                            Spacer()
                            
                            if isNext {
                                Text("Berikutnya")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            
                            Text(schedule.formattedTime(for: item.prayer, timeZone: vm.locationManager.currentTimeZone))
                                .font(.system(size: 12, weight: isNext ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isNext ? .orange : (isPassed ? .white.opacity(0.4) : .white))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isNext ? Color.white.opacity(0.08) : Color.clear)
                        .cornerRadius(6)
                    }
                }
            }
            
            // Footer note
            HStack {
                Text("Kemenag RI (Subuh 20°, Isya 18°, Syafi'i) • Perhitungan Offline")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Text(vm.locationManager.currentTimeZone.identifier)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(
            ZStack {
                Color.black.opacity(0.94)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }
}
