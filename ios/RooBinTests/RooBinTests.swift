import Foundation
import Testing
import UIKit
@testable import RooBin

struct RooBinTests {
    private struct TestResponse: Codable, Sendable {
        let value: String
    }

    @Test
    func initialShellBuilds() {
        #expect(true)
    }

    @Test
    func matchAggregateUsesWebContractKeys() throws {
        let aggregate = MatchAggregateDTO(
            id: UUID(),
            teamID: UUID(),
            date: "2026-07-31",
            seasonID: UUID(),
            opponent: "Visitors",
            submitted: false,
            venue: "home",
            players: [
                .init(playerID: UUID(), isDriver: true)
            ]
        )

        let object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(aggregate)
            ) as? [String: Any]
        )
        #expect(object["teamId"] != nil)
        #expect(object["seasonId"] != nil)
        #expect(object["teamID"] == nil)

        let players = try #require(object["players"] as? [[String: Any]])
        #expect(players.first?["playerId"] != nil)
    }

    @Test
    func errorsExposeSafeMessages() {
        #expect(RooBinError.forbidden.errorDescription?.contains("permission") == true)
        #expect(RooBinError.unexpected.errorDescription?.contains("database") == false)
    }

    @Test
    @MainActor
    func emailOTPRequiresEightNumericDigits() {
        #expect(EmailOTPView.isValidCode("12345678"))
        #expect(!EmailOTPView.isValidCode("123456"))
        #expect(!EmailOTPView.isValidCode("1234567x"))
    }

    @Test
    func deletedSeasonFallsBackToAllSeasons() {
        let missingSeasonID = UUID()
        let selection = SeasonSelection.season(missingSeasonID)

        #expect(selection.validated(against: []) == .all)
    }

    @Test
    func dashboardCollectionRateRoundsToWholePercent() {
        let model = HomeDashboardModel(
            teamName: "Test",
            teamLogoURL: nil,
            seasons: [],
            selectedSeason: .all,
            total: 3,
            paid: 2,
            outstanding: 1,
            matchCount: 1,
            fineCount: 1,
            subCount: 0,
            playerBalances: []
        )

        #expect(model.collectionRate == 67)
    }

    @Test
    @MainActor
    func logoProcessingProducesBoundedMetadataFreeJPEG() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1_600, height: 900)).image { context in
            context.cgContext.setFillColor(UIColor.systemOrange.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1_600, height: 900))
        }
        let cropped = TeamSettingsView.render(source, mode: .crop)
        let fitted = TeamSettingsView.render(source, mode: .fit)
        #expect(cropped.size == CGSize(width: 512, height: 512))
        #expect(fitted.size == CGSize(width: 512, height: 512))
        let data = try #require(TeamSettingsView.compressedJPEG(cropped))
        #expect(data.count <= 400_000)
        #expect(UIImage(data: data) != nil)
    }

    @Test
    func roleLabelsAreAccessibleText() {
        #expect(TeamMembershipDTO.Role.captain.displayName == "Captain")
        #expect(TeamMembershipDTO.Role.viceCaptain.displayName == "Vice-captain")
        #expect(TeamMembershipDTO.Role.member.displayName == "Member")
    }

    @Test
    func accountDeletionPreflightDecodesServerContract() throws {
        let teamID = UUID()
        let data = try JSONSerialization.data(withJSONObject: [
            "email": "player@example.test",
            "captaincyBlockers": [[
                "teamId": teamID.uuidString,
                "teamName": "Pool Team",
                "otherActiveMembers": 2
            ]],
            "teamsDeletedWithAccount": [],
            "historicalFineCount": 3,
            "historicalSubCount": 4,
            "deletionIsImmediate": true,
            "historicalAliasPolicy": "sport_aware_team_specific"
        ])
        let preflight = try JSONDecoder().decode(AccountDeletionPreflight.self, from: data)
        #expect(preflight.email == "player@example.test")
        #expect(preflight.captaincyBlockers.first?.teamID == teamID)
        #expect(preflight.historicalFineCount + preflight.historicalSubCount == 7)
        #expect(preflight.deletionIsImmediate)
    }

    @Test
    func teamLogoStoragePathNormalisesUUIDCase() {
        let teamID = UUID(uuidString: "ABCDEF12-3456-4789-ABCD-EF1234567890")!
        let versionID = UUID(uuidString: "FEDCBA98-7654-4321-ABCD-0123456789AB")!
        #expect(
            SupabaseTeamClient.teamLogoObjectPath(teamID: teamID, versionID: versionID)
                == "abcdef12-3456-4789-abcd-ef1234567890/logo-fedcba98-7654-4321-abcd-0123456789ab.jpg"
        )
    }

    @Test
    func networkClientDecodesSuccessAndSendsDefensiveHeaders() async throws {
        let idempotencyKey = URLProtocolStub.expectedIdempotencyKey

        let client = NetworkClient(baseURL: URL(string: "https://example.test")!, session: stubbedSession())
        let response: TestResponse = try await client.send(
            APIRequest(
                method: .post,
                path: "success",
                body: Data("{}".utf8),
                idempotencyKey: idempotencyKey
            )
        )
        #expect(response.value == "ok")
    }

    @Test(arguments: [
        (401, RooBinError.unauthenticated),
        (403, RooBinError.forbidden),
        (404, RooBinError.notFound),
        (409, RooBinError.conflict),
        (410, RooBinError.expired),
        (429, RooBinError.rateLimited),
        (503, RooBinError.serviceUnavailable),
        (418, RooBinError.unexpected)
    ])
    func networkClientMapsHTTPFailures(status: Int, expected: RooBinError) async {
        let client = NetworkClient(baseURL: URL(string: "https://example.test")!, session: stubbedSession())

        do {
            let _: TestResponse = try await client.send(
                APIRequest(method: .get, path: "status/\(status)")
            )
            Issue.record("Expected HTTP status \(status) to fail")
        } catch let error as RooBinError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected RooBinError, received \(error)")
        }
    }

    @Test
    func networkClientRejectsMalformedSuccessWithoutLeakingDetails() async {
        let client = NetworkClient(baseURL: URL(string: "https://example.test")!, session: stubbedSession())

        do {
            let _: TestResponse = try await client.send(
                APIRequest(method: .get, path: "malformed")
            )
            Issue.record("Expected malformed JSON to fail")
        } catch let error as RooBinError {
            #expect(error == .unexpected)
            #expect(error.errorDescription == "Something went wrong. Please try again.")
        } catch {
            Issue.record("Expected RooBinError, received \(error)")
        }
    }

    private func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    static let expectedIdempotencyKey = UUID(uuidString: "47A1690A-8414-44C8-81CC-1732C4A4B212")!

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let url = try #require(request.url)
            let path = url.path
            let status: Int
            let data: Data
            if path.hasSuffix("/success") {
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
                #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store, no-cache")
                #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == Self.expectedIdempotencyKey.uuidString)
                status = 200
                data = Data(#"{"value":"ok"}"#.utf8)
            } else if path.hasSuffix("/malformed") {
                status = 200
                data = Data("not-json".utf8)
            } else if let value = Int(path.split(separator: "/").last ?? "") {
                status = value
                data = Data()
            } else {
                throw RooBinError.unexpected
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
