// The trust rule table (docs/trust.md section 1) row by row, against the
// patched tree's custom/custom_trust_rules.h. Built and run by CI:
//   g++ -std=c++20 -I <tree>/Telegram/SourceFiles trust_rules_test.cpp
#include "custom/custom_trust_rules.h"

#include <cstdio>

using namespace Custom::TrustRules;

namespace {

int failures = 0;

void Expect(bool ok, const char *what) {
	if (!ok) {
		std::printf("FAIL: %s\n", what);
		++failures;
	}
}

constexpr auto kDay = std::int64_t(86400);
constexpr auto kNow = std::int64_t(2'000'000'000);

Input Person(int activeDays = 0, bool contact = false) {
	auto in = Input();
	in.kind = Kind::Person;
	in.activeDays = activeDays;
	in.contact = contact;
	in.now = kNow;
	return in;
}

Input Chat(Kind kind, bool creatorOrAdmin = false, Mark mark = Mark::None) {
	auto in = Input();
	in.kind = kind;
	in.creatorOrAdmin = creatorOrAdmin;
	in.mark = mark;
	in.now = kNow;
	return in;
}

} // namespace

int main() {
	const auto s = Settings(); // defaults: on, N 3, D 90, grace 90, 4 and 7 on

	// Rule 0
	auto off = s;
	off.on = false;
	Expect(Decide(Chat(Kind::Group), off) == Why::Off, "off trusts everything");
	Expect(IsTrusted(Why::Off), "off is trusted");

	// Rule 1 beats everything after it, admin included
	Expect(Decide(Chat(Kind::Channel, true, Mark::Never), s) == Why::Never,
		"never-trust beats admin");
	auto never = Person(30, true);
	never.mark = Mark::Never;
	Expect(Decide(never, s) == Why::Never, "never-trust beats active contact");

	// Rule 2
	Expect(Decide(Chat(Kind::Self), s) == Why::Own, "Saved Messages");
	Expect(Decide(Chat(Kind::Service), s) == Why::Own, "service account");

	// Rule 3: hand marks on groups, channels, bots never decay
	auto bot = Chat(Kind::Bot, false, Mark::Trusted);
	bot.markedAt = kNow - 1000 * kDay;
	Expect(Decide(bot, s) == Why::Hand, "hand-marked bot, no decay");
	Expect(Decide(Chat(Kind::Group, false, Mark::Trusted), s) == Why::Hand,
		"hand-marked group");

	// Rule 4
	Expect(Decide(Chat(Kind::Group, true), s) == Why::Admin, "own group");
	Expect(Decide(Chat(Kind::Channel, true), s) == Why::Admin, "own channel");
	Expect(Decide(Chat(Kind::Group, false), s) == Why::Untrusted,
		"non-creator supergroup admin is untrusted");
	auto noAdmin = s;
	noAdmin.admin = false;
	Expect(Decide(Chat(Kind::Group, true), noAdmin) == Why::Untrusted,
		"rule 4 off");

	// Rule 5: grace
	auto marked = Person(0);
	marked.mark = Mark::Trusted;
	marked.markedAt = kNow - 90 * kDay + 1;
	Expect(Decide(marked, s) == Why::Grace, "inside grace");
	marked.markedAt = kNow - 90 * kDay;
	Expect(Decide(marked, s) == Why::Dormant, "grace expired: dormant");
	Expect(!IsTrusted(Why::Dormant), "dormant is untrusted");

	// Rule 6: marked person, active enough, revives
	marked.activeDays = 3;
	Expect(Decide(marked, s) == Why::Active, "marked and active");
	marked.activeDays = 2;
	Expect(Decide(marked, s) == Why::Dormant, "marked, one day short");

	// Rule 7
	Expect(Decide(Person(3, true), s) == Why::ActiveContact, "active contact");
	Expect(Decide(Person(2, true), s) == Why::Untrusted, "contact, one day short");
	Expect(Decide(Person(30, false), s) == Why::Untrusted,
		"non-contact only by hand");
	auto noContacts = s;
	noContacts.contacts = false;
	Expect(Decide(Person(30, true), noContacts) == Why::Untrusted, "rule 7 off");

	// Bots only by hand
	auto activeBot = Chat(Kind::Bot);
	activeBot.contact = true;
	activeBot.activeDays = 30;
	Expect(Decide(activeBot, s) == Why::Untrusted, "bots never by activity");

	// Rule 9
	Expect(Decide(Chat(Kind::Channel), s) == Why::Untrusted, "stranger channel");
	Expect(Decide(Person(), s) == Why::Untrusted, "stranger");

	if (failures) {
		std::printf("%d failure(s)\n", failures);
		return 1;
	}
	std::printf("ok: trust rules\n");
	return 0;
}
