import Foundation

/// Which resource a triage hit points to. Distinct from severity — poisoning that hasn't
/// caused symptoms yet genuinely calls for Poison Control, not a 911 dispatch, and
/// crisis language without a stated plan calls for a supportive line, not an ER banner.
enum TriageTier {
    case emergency911
    case poisonControl
    case supportiveCrisis
}

/// What the deterministic layer decided, and the exact copy to show for it. Kept
/// self-contained (rather than switching on `tier` at the call site) so each category's
/// wording can stay accurate to its own source instead of collapsing into one generic
/// "seek care" banner.
struct TriageResult {
    let tier: TriageTier
    let title: String
    let message: String

    /// Shown when Help & Support's "preview the safety banner" toggle is on — a stand-in
    /// example so that screen can demonstrate the banner without a real trigger.
    static let previewSample = TriageResult(
        tier: .emergency911,
        title: "Seek care now",
        message: "What you described may need urgent attention. Call 911 or go to your nearest emergency room."
    )
}

/// Deterministic, keyword/phrase-based safety triage that runs on every user message
/// *before* the RAG chat model ever composes a reply. This is intentionally not left to
/// the chat model's judgment.
///
/// Why: a 2026 Mount Sinai / Nature Medicine study tested a general chat model against
/// physician-determined emergency cases and found it under-triaged more than half of the
/// genuine emergencies — including a case where the model's own explanation named
/// early respiratory-failure warning signs and still advised waiting. Suicide-risk
/// detection was the least reliable category of all, and in the worst way: crisis
/// warnings fired more reliably on lower-risk phrasing than on messages describing an
/// actual plan. See `red-flag-triage-rules.md` in the project docs for the full rule
/// set, category-by-category sourcing, and open follow-ups (this pass is a first
/// implementation of that rule set — it still needs adversarial testing and a clinical
/// safety review before launch; see "What's still needed" there).
///
/// When this fires, it fully replaces the turn: no remedy suggestions, no model call.
/// A true red flag doesn't sit alongside a home-remedy answer — it takes over the turn.
enum RedFlagTriage {

    static func evaluate(_ rawText: String) -> TriageResult? {
        let text = normalize(rawText)
        guard !text.isEmpty else { return nil }

        // Plan/intent/means/recent-attempt language is checked first and wins immediately
        // — it's already the highest-urgency tier (911-equivalent), so there's no ordering
        // risk in returning right away, same as any other emergency category below.
        if matchesAny(text, mentalHealthPlanIntentPatterns) { return mentalHealthPlanIntentResult }

        if matchesAny(text, opioidOverdosePatterns) { return opioidOverdoseResult }
        if isPoisoningEmergency(text) { return poisoningEmergencyResult }
        if matchesAny(text, anaphylaxisPatterns) { return anaphylaxisResult }
        if matchesAny(text, strokePatterns) { return strokeResult }
        if matchesAny(text, cardiacPatterns) { return cardiacResult }
        if matchesAny(text, respiratoryPatterns) { return respiratoryResult }
        if matchesAny(text, neurologicalPatterns) { return neurologicalResult }
        if matchesAny(text, bleedingPatterns) { return bleedingResult }
        if matchesAny(text, highFeverRedFlagPatterns) { return highFeverRedFlagResult }
        if let result = pediatricFever(text) { return result }
        if matchesAny(text, pregnancyPatterns) { return pregnancyResult }
        if matchesAny(text, poisoningNonEmergencyPatterns) { return poisoningNonEmergencyResult }

        // Ideation-only language ("wish I were dead" etc.) is checked LAST, as a fallback
        // below every physical-emergency category. That's deliberate: a message describing
        // both somatic distress and despair (a real, plausible combination) needs the
        // physical-emergency response, not the lower-urgency supportive-crisis one — the
        // supportive banner should only show when nothing more urgent was also described.
        if matchesAny(text, mentalHealthIdeationPatterns) { return mentalHealthIdeationResult }

        return nil
    }

    // MARK: - Matching helpers

    /// Lowercases and strips apostrophes so "can't" / "cant" and similar contractions
    /// match one written form of each pattern instead of needing every variant twice.
    private static func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "'", with: "")
    }

    private static func matchesAny(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }

    private static func firstDoubleMatch(_ pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[valueRange])
    }

    private static func firstIntMatch(_ pattern: String, in text: String) -> Int? {
        guard let value = firstDoubleMatch(pattern, in: text) else { return nil }
        return Int(value)
    }

    // MARK: - Mental health crisis (Columbia Protocol / C-SSRS)

    /// Source: Columbia Lighthouse Project (C-SSRS); SAMHSA 988. The clinical signal is
    /// *ideation vs. plan/intent/means*, not the mere presence of a word like "suicide" —
    /// so these two lists are checked in order, plan/intent first, and only one fires.
    private static let mentalHealthPlanIntentPatterns = [
        "kill myself", "kill me", "end my life", "ending my life",
        "suicide plan", "plan to kill", "planning to kill myself",
        "how i would kill myself", "how id kill myself", "how to kill myself",
        "thinking about how id do it", "thinking about how i would do it",
        "going to overdose on purpose", "going to od on purpose",
        "tried to kill myself", "attempted suicide", "tried to end my life",
        "i have pills and im going to", "i have a gun and im going to",
        "i have the means to kill myself", "i have a way to kill myself",
        "wrote a suicide note", "suicide note",
    ]
    private static let mentalHealthIdeationPatterns = [
        "wish i were dead", "wish i was dead",
        "wish i could go to sleep and not wake up", "wish i wouldnt wake up",
        "thoughts of suicide", "thinking about suicide", "suicidal thoughts",
        "i want to die", "i dont want to be alive", "i dont want to live anymore",
        "life isnt worth living", "better off dead", "want to end it all",
        "no reason to keep going",
    ]

    private static let mentalHealthPlanIntentResult = TriageResult(
        tier: .emergency911,
        title: "Reach out right now",
        message: "What you described sounds like it could be a crisis. Call or text 988 (Suicide & Crisis Lifeline) now, or call 911. If you can, stay with someone or ask someone to stay with you."
    )
    private static let mentalHealthIdeationResult = TriageResult(
        tier: .supportiveCrisis,
        title: "You don't have to go through this alone",
        message: "If you're struggling, free and confidential support is available anytime. Call or text 988 (Suicide & Crisis Lifeline) to talk with someone now."
    )

    // MARK: - Opioid overdose

    /// Source: CDC, "What to Do If You Think Someone Is Overdosing." Checked ahead of the
    /// generic poisoning categories since it has its own, more specific response (naloxone).
    private static let opioidOverdosePatterns = [
        "wont wake up after taking", "wont wake up after he took", "wont wake up after she took",
        "slow breathing and wont wake", "shallow breathing and wont wake",
        "blue lips and wont wake", "gurgling sounds and wont wake", "gurgling and unresponsive",
        "pinpoint pupils", "possible overdose", "think hes overdosing", "think shes overdosing",
        "took too many pills and wont wake", "od and wont wake up",
    ]
    private static let opioidOverdoseResult = TriageResult(
        tier: .emergency911,
        title: "This looks like it could be an overdose",
        message: "Give naloxone (Narcan) now if you have it, call 911, and keep them on their side. CDC guidance: if you aren't sure, treat it like an overdose."
    )

    // MARK: - Poisoning

    /// Source: Mass. Dept. of Public Health, "When to Call the Poison Control Center, and
    /// When to Call 911." Split into two tiers on purpose — a conscious, breathing person
    /// who may have gotten into something needs Poison Control, not a 911 dispatch.
    ///
    /// This is a co-occurrence check (an ingestion word + a collapse symptom, anywhere in
    /// the message) rather than a fixed phrase list — an earlier version only recognized
    /// "swallowed something and stopped breathing" verbatim and missed the equally common
    /// "swallowed pills and stopped breathing" / "took pills and passed out" phrasing.
    /// Caught in adversarial testing; a fixed-phrase list keeps needing every noun (pills,
    /// medication, chemical, cleaner...) spelled out, which is exactly the kind of gap a
    /// safety net can't afford.
    private static let poisoningIngestionWords = ["swallowed", "took", "ate", "drank", "ingested"]
    private static let poisoningSevereSymptoms = [
        "stopped breathing", "had a seizure", "passed out", "collapsed",
        "cant be woken", "cant wake", "unconscious", "not breathing", "unresponsive",
    ]
    private static func isPoisoningEmergency(_ text: String) -> Bool {
        matchesAny(text, poisoningIngestionWords) && matchesAny(text, poisoningSevereSymptoms)
    }
    private static let poisoningEmergencyResult = TriageResult(
        tier: .emergency911,
        title: "This is a poisoning emergency",
        message: "Call 911 now."
    )

    private static let poisoningNonEmergencyPatterns = [
        "might have swallowed something", "kid ate something he shouldnt have",
        "child swallowed a pill", "swallowed a household chemical", "ate a plant i dont recognize",
        "took too much of a supplement", "accidentally took double dose",
        "swallowed cleaning product", "got into the medicine cabinet", "swallowed a battery",
        "ate my vitamins", "ate some vitamins", "ate a vitamin", "ate a few vitamins",
        "of my vitamins", "took too many vitamins", "swallowed a vitamin",
    ]
    private static let poisoningNonEmergencyResult = TriageResult(
        tier: .poisonControl,
        title: "Contact Poison Control",
        message: "Call Poison Control at 1-800-222-1222 right away — don't wait for symptoms, and don't try home remedies without their guidance. Call 911 instead if the person is unconscious, not breathing normally, or can't be woken."
    )

    // MARK: - Anaphylaxis

    /// Source: FARE, "Signs and Symptoms of Anaphylaxis."
    private static let anaphylaxisPatterns = [
        "throat is swelling", "tongue is swelling", "throat feels like its closing",
        "throat closing up", "trouble swallowing after eating", "trouble breathing after eating",
        "hives and trouble breathing", "allergic reaction and trouble breathing",
        "swelling after a bee sting", "swelling after a sting", "anaphylaxis", "anaphylactic",
        "used my epipen", "used my epi pen", "throat tightening",
    ]
    private static let anaphylaxisResult = TriageResult(
        tier: .emergency911,
        title: "This could be a severe allergic reaction",
        message: "Use an epinephrine auto-injector now if one is available, then call 911 — even if symptoms seem to improve afterward, a second wave (biphasic reaction) can follow hours later."
    )

    // MARK: - Stroke (BE-FAST)

    /// Source: CDC "Signs and Symptoms of Stroke"; American Stroke Association BE-FAST.
    private static let strokePatterns = [
        "face is drooping", "face drooping", "one side of my face is drooping",
        "arm is drifting down", "arm keeps drifting down", "one arm wont stay up",
        "slurred speech", "suddenly slurring", "sudden trouble speaking",
        "cant speak clearly all of a sudden", "sudden dizziness and cant balance",
        "sudden loss of balance", "sudden trouble seeing", "vision suddenly went",
        "sudden confusion", "suddenly confused and cant explain why",
        "suddenly cant find the right words",
    ]
    private static let strokeResult = TriageResult(
        tier: .emergency911,
        title: "This could be a stroke",
        message: "Call 911 immediately and note the time symptoms started. Don't wait to see if it passes, and don't drive to the hospital yourself."
    )

    // MARK: - Cardiac

    /// Source: American Heart Association, "Warning Signs of a Heart Attack." Deliberately
    /// does not require the word "chest" — women's presentation is often anxiety, unusual
    /// fatigue, or upset stomach with little or no classic chest pain.
    private static let cardiacPatterns = [
        "chest pain", "chest pressure", "chest squeezing", "squeezing in my chest", "chest feels tight",
        "chest tightness",
        "chest fullness", "crushing chest", "chest pain spreading", "pain spreading to my arm",
        "pain spreading to my jaw", "pain radiating to my arm", "pain radiating to my jaw",
        "pain radiating to my back", "pain in my jaw and chest", "cold sweat and chest pain",
        "chest pain and nausea", "chest pain and lightheaded", "chest pain and shortness of breath",
        "sudden chest pain", "heart attack symptoms", "think im having a heart attack",
    ]
    private static let cardiacResult = TriageResult(
        tier: .emergency911,
        title: "This could be a heart attack",
        message: "Call 911 now — don't drive yourself. Stay as calm and still as you can while you wait for help."
    )

    // MARK: - Respiratory distress

    /// Source: general emergency-medicine presentation; the asthma/COPD scenario named
    /// here is the same one the Mount Sinai study found a chat model missed.
    private static let respiratoryPatterns = [
        "trouble breathing", "having trouble breathing", "cant breathe", "gasping for air",
        "cant speak in full sentences", "cant catch my breath", "wheezing that wont stop",
        "wheezing and getting worse", "lips are blue", "lips turning blue",
        "fingertips are blue", "turning blue", "asthma attack not improving",
        "inhaler isnt working", "cant get enough air",
    ]
    private static let respiratoryResult = TriageResult(
        tier: .emergency911,
        title: "This may be a breathing emergency",
        message: "Call 911 now, especially if a rescue inhaler isn't helping or lips/fingertips look blue or gray."
    )

    // MARK: - Neurological

    /// Sources: Harvard Health on thunderclap headache; CDC "First Aid for Seizures"
    /// (5-minute / repeat-seizure / breathing-trouble thresholds).
    private static let neurologicalPatterns = [
        "worst headache of my life", "worst headache ive ever had",
        "sudden severe headache", "thunderclap headache", "headache came on in seconds",
        "lost consciousness", "passed out and wont wake up", "seizure lasting",
        "seizure for more than 5 minutes", "having a seizure right now",
        "second seizure", "another seizure right after", "not breathing after a seizure",
        "cant wake him up", "cant wake her up", "cant wake them up", "unresponsive",
    ]
    private static let neurologicalResult = TriageResult(
        tier: .emergency911,
        title: "This may be a neurological emergency",
        message: "Call 911 now. For a seizure: don't hold the person down, clear the area, and time it — call 911 if it passes 5 minutes or a second one follows."
    )

    // MARK: - Uncontrolled bleeding

    /// Source: American Red Cross, "Bleeding (Life-Threatening External)."
    private static let bleedingPatterns = [
        "wont stop bleeding", "bleeding wont stop", "cant stop the bleeding", "cant stop bleeding",
        "wont stop the bleeding", "bleeding is spurting", "blood is spurting", "its spurting blood",
        "bleeding and feels faint", "bleeding and looks pale", "vomiting blood", "throwing up blood",
        "blood in my stool", "blood in stool", "bleeding through the bandage",
        "lost a lot of blood",
    ]
    private static let bleedingResult = TriageResult(
        tier: .emergency911,
        title: "This may be life-threatening bleeding",
        message: "Apply firm, direct pressure with a clean cloth and call 911 now — especially if it hasn't slowed after 10 minutes of steady pressure."
    )

    // MARK: - High fever with red flags (non-pediatric)

    /// Source: Meningitis Research Foundation. The "glass test" (press a clear glass
    /// against a rash — if it's still visible through the glass, that's non-blanching).
    private static let highFeverRedFlagPatterns = [
        "fever and stiff neck", "stiff neck and fever", "fever with a rash that doesnt fade",
        "rash doesnt fade when i press it", "glass test", "rash doesnt disappear under pressure",
        "fever and severe headache and light sensitivity", "sensitive to light and fever",
        "fever and confusion", "fever and seizure", "fever and blue lips",
        "fever and extremely lethargic", "fever and wont wake up",
    ]
    private static let highFeverRedFlagResult = TriageResult(
        tier: .emergency911,
        title: "This combination needs care today",
        message: "Fever together with a stiff neck, a rash that doesn't fade under pressure, confusion, or extreme lethargy can signal a serious infection. Call 911 or go to the emergency room now."
    )

    // MARK: - Pediatric fever (age-threshold based)

    /// Source: AAP / HealthyChildren.org, "Fever and Your Baby." These are the most widely
    /// published pediatric red-flag thresholds and can be applied without a pediatrician on
    /// staff — but extracting age/temperature from freeform chat text is inherently
    /// imperfect. When an age can't be parsed but the message clearly describes a baby, this
    /// falls back to the youngest, most sensitive threshold rather than assuming the least
    /// urgent one. Flagged in the project docs as needing adversarial testing before launch.
    private static func pediatricFever(_ text: String) -> TriageResult? {
        guard let temp = extractTemperatureF(text) else { return nil }

        let ageMonths = firstIntMatch(#"(\d{1,2})\s*[-\s]?(?:month|months|mo)\b"#, in: text)
        let mentionsInfant = matchesAny(text, ["newborn", "my baby", "the baby", "my infant", "our baby"])

        if let ageMonths {
            if ageMonths <= 3, temp >= 100.4 {
                return pediatricFeverResult(ageDescription: "3 months old or younger")
            }
            if ageMonths > 3, ageMonths <= 6, temp >= 101.0 {
                return pediatricFeverResult(ageDescription: "between 3 and 6 months old")
            }
            if ageMonths > 6, temp >= 103.0 {
                return pediatricFeverResult(ageDescription: "older than 6 months")
            }
            return nil
        }

        if mentionsInfant, temp >= 100.4 {
            return pediatricFeverResult(ageDescription: "a baby")
        }
        return nil
    }

    private static func extractTemperatureF(_ text: String) -> Double? {
        if let value = firstDoubleMatch(#"(\d{2,3}(?:\.\d)?)\s*(?:°\s*)?f\b"#, in: text) {
            return value
        }
        return firstDoubleMatch(#"(?:fever|temp|temperature)\s*(?:of|is|was|at)?\s*(\d{2,3}(?:\.\d)?)"#, in: text)
    }

    private static func pediatricFeverResult(ageDescription: String) -> TriageResult {
        TriageResult(
            tier: .emergency911,
            title: "This fever needs same-day care",
            message: "A fever like this in a baby \(ageDescription) needs medical attention right away, even if they otherwise seem okay. Call your pediatrician now or go to the emergency room."
        )
    }

    // MARK: - Pregnancy / postpartum complications

    /// Source: CDC "Hear Her" campaign warning-sign list.
    private static let pregnancyPatterns = [
        "pregnant and severe headache", "pregnant with vision changes", "pregnant and vision changes",
        "pregnant and swelling in my face", "pregnant and hands are swollen", "pregnant and cant breathe",
        "pregnant and chest pain", "pregnant and havent felt the baby move", "baby stopped moving",
        "no fetal movement", "decreased fetal movement", "pregnant and bleeding",
        "pregnant and fluid leaking", "postpartum and heavy bleeding", "postpartum and leg is swollen",
        "postpartum and leg is red and swollen", "postpartum and overwhelming fatigue",
    ]
    private static let pregnancyResult = TriageResult(
        tier: .emergency911,
        title: "This needs medical attention now",
        message: "These can be signs of a serious pregnancy or postpartum complication. Call your OB/midwife now, or 911 if it feels severe."
    )
}
