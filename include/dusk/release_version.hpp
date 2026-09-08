#ifndef DUSK_RELEASE_VERSION_HPP
#define DUSK_RELEASE_VERSION_HPP

#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace dusk::release_version {

struct Version {
    int major = 0;
    int minor = 0;
    int patch = 0;
    int revision = 0;
    std::vector<std::string> prerelease;
};

std::optional<Version> parse(std::string_view value);
int compare(const Version& lhs, const Version& rhs);

}  // namespace dusk::release_version

#endif  // DUSK_RELEASE_VERSION_HPP
