// The trust rule table (docs/trust.md section 1) row by row, against the
// patched tree's org/telegram/messenger/TrustRules.java. Same cases as
// desktop/tests/trust_rules_test.cpp, plus the per-message clauses. CI:
//   javac -d out <tree>/.../TrustRules.java android/tests/TrustRulesTest.java
//   java -cp out TrustRulesTest
import org.telegram.messenger.TrustRules;

import static org.telegram.messenger.TrustRules.*;

public class TrustRulesTest {

    static int failures = 0;

    static void expect(boolean ok, String what) {
        if (!ok) {
            System.out.println("FAIL: " + what);
            failures++;
        }
    }

    static final long DAY = 86400;
    static final long NOW = 2_000_000_000L;

    static int person(int activeDays, boolean contact, int mark, long markedAt, Settings s) {
        return decide(KIND_PERSON, false, contact, mark, markedAt, activeDays, NOW, s);
    }

    static int chat(int kind, boolean creatorOrAdmin, int mark, Settings s) {
        return decide(kind, creatorOrAdmin, false, mark, 0, 0, NOW, s);
    }

    public static void main(String[] args) {
        final Settings s = new Settings(); // defaults: on, N 3, D 90, grace 90, 4 and 7 on, 8 off
        expect(s.on && s.n == 3 && s.d == 90 && s.grace == 90 && s.admin && s.contacts && !s.sender && s.tap && s.relay, "defaults");

        // Rule 0
        final Settings off = new Settings();
        off.on = false;
        expect(chat(KIND_GROUP, false, MARK_NONE, off) == WHY_OFF, "off trusts everything");
        expect(isTrusted(WHY_OFF), "off is trusted");

        // Rule 1 beats everything after it, admin included
        expect(chat(KIND_CHANNEL, true, MARK_NEVER, s) == WHY_NEVER, "never-trust beats admin");
        expect(person(30, true, MARK_NEVER, 0, s) == WHY_NEVER, "never-trust beats active contact");

        // Rule 2
        expect(chat(KIND_SELF, false, MARK_NONE, s) == WHY_OWN, "Saved Messages");
        expect(chat(KIND_SERVICE, false, MARK_NONE, s) == WHY_OWN, "service account");
        expect(SERVICE_USER_ID == 777000L, "service account is 777000 exactly");

        // Rule 3: hand marks on groups, channels, bots never decay
        expect(decide(KIND_BOT, false, false, MARK_TRUSTED, NOW - 1000 * DAY, 0, NOW, s) == WHY_HAND, "hand-marked bot, no decay");
        expect(chat(KIND_GROUP, false, MARK_TRUSTED, s) == WHY_HAND, "hand-marked group");

        // Rule 4
        expect(chat(KIND_GROUP, true, MARK_NONE, s) == WHY_ADMIN, "own group");
        expect(chat(KIND_CHANNEL, true, MARK_NONE, s) == WHY_ADMIN, "own channel");
        expect(chat(KIND_GROUP, false, MARK_NONE, s) == WHY_UNTRUSTED, "non-creator supergroup admin is untrusted");
        final Settings noAdmin = new Settings();
        noAdmin.admin = false;
        expect(chat(KIND_GROUP, true, MARK_NONE, noAdmin) == WHY_UNTRUSTED, "rule 4 off");

        // Rule 5: grace
        expect(person(0, false, MARK_TRUSTED, NOW - 90 * DAY + 1, s) == WHY_GRACE, "inside grace");
        expect(person(0, false, MARK_TRUSTED, NOW - 90 * DAY, s) == WHY_DORMANT, "grace expired: dormant");
        expect(!isTrusted(WHY_DORMANT), "dormant is untrusted");
        final Settings noGrace = new Settings();
        noGrace.grace = 0;
        expect(person(0, false, MARK_TRUSTED, NOW, noGrace) == WHY_DORMANT, "grace 0: dormant at once");

        // Rule 6: marked person, active enough, revives
        expect(person(3, false, MARK_TRUSTED, NOW - 200 * DAY, s) == WHY_ACTIVE, "marked and active");
        expect(person(2, false, MARK_TRUSTED, NOW - 200 * DAY, s) == WHY_DORMANT, "marked, one day short");

        // Rule 7
        expect(person(3, true, MARK_NONE, 0, s) == WHY_ACTIVE_CONTACT, "active contact");
        expect(person(2, true, MARK_NONE, 0, s) == WHY_UNTRUSTED, "contact, one day short");
        expect(person(30, false, MARK_NONE, 0, s) == WHY_UNTRUSTED, "non-contact only by hand");
        final Settings noContacts = new Settings();
        noContacts.contacts = false;
        expect(person(30, true, MARK_NONE, 0, noContacts) == WHY_UNTRUSTED, "rule 7 off");

        // Bots only by hand
        expect(decide(KIND_BOT, false, true, MARK_NONE, 0, 30, NOW, s) == WHY_UNTRUSTED, "bots never by activity");

        // Rule 9
        expect(chat(KIND_CHANNEL, false, MARK_NONE, s) == WHY_UNTRUSTED, "stranger channel");
        expect(person(0, false, MARK_NONE, 0, s) == WHY_UNTRUSTED, "stranger");

        // Per message: rule 2's own clause, rule 8, and "never" beating both
        expect(allowsMessage(WHY_UNTRUSTED, true, -1, s), "own message loads in an untrusted chat");
        expect(!allowsMessage(WHY_NEVER, true, -1, s), "never beats your own message");
        expect(!allowsMessage(WHY_UNTRUSTED, false, WHY_ACTIVE_CONTACT, s), "rule 8 off by default");
        final Settings sender = new Settings();
        sender.sender = true;
        expect(allowsMessage(WHY_UNTRUSTED, false, WHY_ACTIVE_CONTACT, sender), "rule 8 on: trusted sender");
        expect(!allowsMessage(WHY_UNTRUSTED, false, WHY_DORMANT, sender), "rule 8: dormant sender is not trusted");
        expect(!allowsMessage(WHY_NEVER, false, WHY_ACTIVE_CONTACT, sender), "never beats rule 8");
        expect(allowsMessage(WHY_ADMIN, false, -1, s), "trusted chat");

        // Local day
        expect(day(0, 0) == 0 && day(86399, 0) == 0 && day(86400, 0) == 1, "day boundaries");
        expect(day(86399, 3600) == 1 && day(0, -3600) == -1, "zone offset");

        if (failures > 0) {
            System.out.println(failures + " failure(s)");
            System.exit(1);
        }
        System.out.println("ok: trust rules");
    }
}
