#include "update_check.hpp"

#include "dusk/http/http.hpp"
#include "dusk/release_version.hpp"
#include "fmt/format.h"
#include "nlohmann/json.hpp"
#include "version.h"

#include <optional>
#include <string_view>
#include <utility>

namespace dusk::update_check {
namespace {

using json = nlohmann::json;

constexpr std::string_view GitHubApiVersion = "2026-03-10";

std::string json_string(const json& value, const char* key) {
    const auto iter = value.find(key);
    if (iter == value.end() || !iter->is_string()) {
        return {};
    }
    return iter->get<std::string>();
}

Release parse_release(const json& value) {
    Release release{
        .tagName = json_string(value, "tag_name"),
        .name = json_string(value, "name"),
        .htmlUrl = json_string(value, "html_url"),
        .body = json_string(value, "body"),
    };

    const auto assets = value.find("assets");
    if (assets != value.end() && assets->is_array()) {
        for (const auto& asset : *assets) {
            if (!asset.is_object()) {
                continue;
            }
            release.assets.push_back({
                .name = json_string(asset, "name"),
                .browserDownloadUrl = json_string(asset, "browser_download_url"),
                .digest = json_string(asset, "digest"),
            });
        }
    }

    return release;
}

std::string release_url(std::string_view owner, std::string_view repo) {
    return fmt::format("https://api.github.com/repos/{}/{}/releases/latest", owner, repo);
}

std::string user_agent() {
    return fmt::format("Dusk/{}", DUSK_WC_DESCRIBE);
}

}  // namespace

Result check_latest_github_release(std::string_view owner, std::string_view repo) {
    if (!http::available()) {
        return {
            .status = Status::Disabled,
            .message = "No HTTP backend is available",
        };
    }
    if (owner.empty() || repo.empty()) {
        return {
            .status = Status::Failed,
            .message = "GitHub owner and repo are required",
        };
    }

    http::Request request{
        .url = release_url(owner, repo),
        .headers =
            {
                {.name = "User-Agent", .value = user_agent()},
                {.name = "Accept", .value = "application/vnd.github+json"},
                {.name = "X-GitHub-Api-Version", .value = std::string(GitHubApiVersion)},
            },
    };

    http::Result result = http::get(request);
    if (result.error != http::Error::None) {
        return {
            .status = Status::Failed,
            .message = result.message,
        };
    }
    if (result.response.statusCode != 200) {
        return {
            .status = Status::Failed,
            .message = fmt::format("GitHub returned HTTP {}", result.response.statusCode),
        };
    }

    Release latest;
    try {
        latest = parse_release(json::parse(result.response.body));
    } catch (const std::exception& e) {
        return {
            .status = Status::Failed,
            .message = fmt::format("Failed to parse GitHub release JSON: {}", e.what()),
        };
    }

    const std::optional<release_version::Version> latestVersion =
        release_version::parse(latest.tagName);
    const std::optional<release_version::Version> currentVersion =
        release_version::parse(DUSK_WC_DESCRIBE);
    if (!latestVersion) {
        return {
            .status = Status::Failed,
            .message = fmt::format("Failed to parse release tag '{}'", latest.tagName),
            .latest = std::move(latest),
        };
    }
    if (!currentVersion) {
        return {
            .status = Status::Failed,
            .message = fmt::format("Failed to parse Dusklight version '{}'", DUSK_WC_DESCRIBE),
            .latest = std::move(latest),
        };
    }

    const bool updateAvailable = release_version::compare(*latestVersion, *currentVersion) > 0;
    return {
        .status = updateAvailable ? Status::UpdateAvailable : Status::UpToDate,
        .message = updateAvailable ? "Update available" : "Dusklight is up to date",
        .latest = std::move(latest),
    };
}

}  // namespace dusk::update_check
