import AVFAudio
import CoreLocation
import EventKit
import Observation
import Photos
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(RelationshipStore.self) private var relationshipStore
    @State private var showsDeleteConfirmation = false
    @State private var showsUnlinkConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("settings.account.section") {
                if let profile = session.profile {
                    LabeledContent("settings.account.name") {
                        Text(verbatim: profile.displayName)
                    }
                }

                Button("settings.sign_out") {
                    Task { await session.signOut() }
                }
            }

            Section {
                Toggle("settings.ai.enabled", isOn: $settings.aiEnabled)
                Toggle(
                    "settings.ai.relationship_score",
                    isOn: $settings.relationshipScoreEnabled
                )
                .disabled(settings.aiEnabled == false)
            } header: {
                Text("settings.ai.section")
            } footer: {
                Text("settings.ai.footer")
            }

            Section {
                Toggle(
                    "settings.privacy.notification_previews",
                    isOn: $settings.notificationPreviewsEnabled
                )
                NavigationLink {
                    PrivacyControlsView()
                } label: {
                    Label("settings.privacy.controls", systemImage: "hand.raised.fill")
                }
            } header: {
                Text("settings.privacy.section")
            } footer: {
                Text("settings.privacy.footer")
            }

            if relationshipStore.relationship.status == .active {
                Section("settings.relationship.section") {
                    Button("settings.relationship.emergency_unlink", role: .destructive) {
                        showsUnlinkConfirmation = true
                    }
                }
            }

            #if DEBUG
            Section("settings.debug.section") {
                if let userID = session.user?.id {
                    LabeledContent("settings.debug.user_id") {
                        Text(verbatim: userID)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Button("settings.debug.restart_onboarding") {
                    settings.resetOnboardingPreferences()
                    Task { await session.debugRestartOnboarding() }
                }

                Button("settings.debug.activate_demo_partner") {
                    guard let userID = session.user?.id else { return }
                    relationshipStore.activateDemoRelationship(
                        currentUserID: userID,
                        locale: settings.language.locale
                    )
                }

                Button(
                    "settings.debug.reset_pairing",
                    role: .destructive,
                    action: resetDebugPairing
                )
            }
            #endif

            Section("settings.about.section") {
                LabeledContent("settings.about.beta") {
                    Text("settings.about.free")
                }
                Link("settings.about.privacy", destination: BrandConfiguration.current.privacyURL)
                Link("settings.about.terms", destination: BrandConfiguration.current.termsURL)
                Link("settings.about.support", destination: supportURL)
            }

            Section {
                Button("settings.delete_account", role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AvenBackground())
        .tint(PremiumArrivalStyle.pinkInk)
        .navigationTitle(Text("settings.title"))
        .confirmationDialog(
            Text("settings.delete.confirm.title"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("settings.delete.confirm.action", role: .destructive) {
                Task { await session.deleteAccount() }
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("settings.delete.confirm.message")
        }
        .confirmationDialog(
            Text("settings.relationship.unlink.confirm.title"),
            isPresented: $showsUnlinkConfirmation,
            titleVisibility: .visible
        ) {
            Button("settings.relationship.unlink.confirm.action", role: .destructive) {
                relationshipStore.endRelationship()
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("settings.relationship.unlink.confirm.message")
        }
    }

    private var supportURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = BrandConfiguration.current.supportEmail
        return components.url ?? BrandConfiguration.current.websiteURL
    }

    #if DEBUG
    private func resetDebugPairing() {
        relationshipStore.reset()
        guard let user = session.user else { return }
        relationshipStore.prepare(
            for: user,
            profile: session.profile,
            locale: settings.language.locale
        )
    }
    #endif
}

private struct PrivacyControlsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissions = PermissionStatusStore()

    var body: some View {
        Form {
            Section {
                permissionRow(
                    "settings.privacy.notifications",
                    status: permissions.notifications,
                    icon: "bell.badge.fill"
                )
                permissionRow(
                    "settings.privacy.photos",
                    status: permissions.photos,
                    icon: "photo.fill"
                )
                permissionRow(
                    "settings.privacy.calendar",
                    status: permissions.calendar,
                    icon: "calendar"
                )
                permissionRow(
                    "settings.privacy.location",
                    status: permissions.location,
                    icon: "location.fill"
                )
                permissionRow(
                    "settings.privacy.microphone",
                    status: permissions.microphone,
                    icon: "mic.fill"
                )

                Button("settings.privacy.request_notifications") {
                    Task {
                        await NotificationAuthorizationClient.requestIfNeeded()
                        await permissions.refresh()
                    }
                }

                Button("settings.privacy.request_location") {
                    Task {
                        await LocationAuthorizationClient.requestAlwaysPreciseIfNeeded()
                        await permissions.refresh()
                    }
                }

                Button("settings.privacy.open_settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    UIApplication.shared.open(url)
                }
            } footer: {
                Text("settings.privacy.permissions_footer")
            }

            Section("settings.privacy.ai.section") {
                Text("settings.privacy.ai.explanation")
                PrivacyBadge(title: "settings.privacy.ai.on_device")
            }
        }
        .navigationTitle(Text("settings.privacy.controls"))
        .task {
            await permissions.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await permissions.refresh() }
            }
        }
    }

    private func permissionRow(
        _ title: LocalizedStringResource,
        status: PermissionStatus,
        icon: String
    ) -> some View {
        LabeledContent {
            Text(status.localizedResource)
                .foregroundStyle(.secondary)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
            }
        }
    }
}

private enum PermissionStatus {
    case enabled
    case denied
    case restricted
    case notRequested

    var localizedResource: LocalizedStringResource {
        switch self {
        case .enabled: "settings.permission.enabled"
        case .denied: "settings.permission.denied"
        case .restricted: "settings.permission.restricted"
        case .notRequested: "settings.permission.not_requested"
        }
    }
}

@MainActor
@Observable
private final class PermissionStatusStore {
    private let locationManager = CLLocationManager()

    var photos: PermissionStatus = .notRequested
    var calendar: PermissionStatus = .notRequested
    var location: PermissionStatus = .notRequested
    var microphone: PermissionStatus = .notRequested
    var notifications: PermissionStatus = .notRequested

    func refresh() async {
        photos = Self.photosStatus(
            PHPhotoLibrary.authorizationStatus(for: .readWrite)
        )
        calendar = Self.eventStatus(
            EKEventStore.authorizationStatus(for: .event)
        )
        location = Self.locationStatus(locationManager.authorizationStatus)
        microphone = Self.microphoneStatus(
            AVAudioApplication.shared.recordPermission
        )
        let notificationSettings = await UNUserNotificationCenter.current()
            .notificationSettings()
        notifications = Self.notificationStatus(notificationSettings.authorizationStatus)
    }

    private static func photosStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .limited: .enabled
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notRequested
        @unknown default: .notRequested
        }
    }

    private static func eventStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .fullAccess, .writeOnly: .enabled
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notRequested
        @unknown default: .notRequested
        }
    }

    private static func locationStatus(
        _ status: CLAuthorizationStatus
    ) -> PermissionStatus {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: .enabled
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notRequested
        @unknown default: .notRequested
        }
    }

    private static func microphoneStatus(
        _ status: AVAudioApplication.recordPermission
    ) -> PermissionStatus {
        switch status {
        case .granted: .enabled
        case .denied: .denied
        case .undetermined: .notRequested
        @unknown default: .notRequested
        }
    }

    private static func notificationStatus(
        _ status: UNAuthorizationStatus
    ) -> PermissionStatus {
        switch status {
        case .authorized, .provisional, .ephemeral: .enabled
        case .denied: .denied
        case .notDetermined: .notRequested
        @unknown default: .notRequested
        }
    }
}
