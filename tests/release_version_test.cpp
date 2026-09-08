#include "dusk/release_version.hpp"

#include <gtest/gtest.h>

namespace {

using dusk::release_version::compare;
using dusk::release_version::parse;

TEST(ReleaseVersion, ParsesNumericAndroidIdentity) {
    const auto version = parse("1.4.1.1");
    ASSERT_TRUE(version.has_value());
    EXPECT_EQ(version->major, 1);
    EXPECT_EQ(version->minor, 4);
    EXPECT_EQ(version->patch, 1);
    EXPECT_EQ(version->revision, 1);
}

TEST(ReleaseVersion, AcceptsVPrefixAndLegacyThreeComponentVersion) {
    const auto current = parse("v1.4.1.1");
    const auto upstream = parse("1.4.1");
    ASSERT_TRUE(current.has_value());
    ASSERT_TRUE(upstream.has_value());
    EXPECT_EQ(upstream->revision, 0);
}

TEST(ReleaseVersion, ComparesRevisionAfterPatch) {
    ASSERT_TRUE(parse("1.4.1.2").has_value());
    ASSERT_TRUE(parse("1.4.1.1").has_value());
    ASSERT_TRUE(parse("1.4.2.0").has_value());
    ASSERT_TRUE(parse("1.4.1.999").has_value());
    EXPECT_GT(compare(*parse("1.4.1.2"), *parse("1.4.1.1")), 0);
    EXPECT_GT(compare(*parse("1.4.2.0"), *parse("1.4.1.999")), 0);
}

TEST(ReleaseVersion, ReleaseOutranksGitDescribePrerelease) {
    const auto release = parse("1.4.1.1");
    const auto development = parse("1.4.1.1-3-gdeadbeef");
    ASSERT_TRUE(release.has_value());
    ASSERT_TRUE(development.has_value());
    EXPECT_GT(compare(*release, *development), 0);
}

TEST(ReleaseVersion, RejectsInvalidNumericIdentity) {
    EXPECT_FALSE(parse("1.4").has_value());
    EXPECT_FALSE(parse("1.4.1.").has_value());
    EXPECT_FALSE(parse("1.4.1.1.2").has_value());
    EXPECT_FALSE(parse("release-1.4.1.1").has_value());
}

}  // namespace
