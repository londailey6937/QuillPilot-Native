//
//  CharacterLibrary.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

// MARK: - Character Model

enum CharacterRole: String, CaseIterable, Codable {
    case protagonist = "Protagonist"
    case antagonist = "Antagonist"
    case supporting = "Supporting"
    case minor = "Minor"

    var color: NSColor {
        switch self {
        case .protagonist: return .systemBlue
        case .antagonist: return .systemRed
        case .supporting: return .systemGreen
        case .minor: return .systemGray
        }
    }
}

struct CharacterProfile: Codable, Identifiable {
    var id: UUID
    var fullName: String
    var nickname: String
    var role: CharacterRole
    var age: String
    var occupation: String
    var appearance: String
    var background: String
    var education: String
    var residence: String
    var family: String
    var pets: String
    var personalityTraits: [String]
    var principles: [String]
    var skills: [String]
    var motivations: String
    var weaknesses: String
    var connections: String
    var quotes: [String]
    var notes: String

    var isSampleCharacter: Bool

    init(id: UUID = UUID(),
         fullName: String = "",
         nickname: String = "",
         role: CharacterRole = .supporting,
         age: String = "",
         occupation: String = "",
         appearance: String = "",
         background: String = "",
         education: String = "",
         residence: String = "",
         family: String = "",
         pets: String = "",
         personalityTraits: [String] = [],
         principles: [String] = [],
         skills: [String] = [],
         motivations: String = "",
         weaknesses: String = "",
         connections: String = "",
         quotes: [String] = [],
         notes: String = "",
         isSampleCharacter: Bool = false) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.role = role
        self.age = age
        self.occupation = occupation
        self.appearance = appearance
        self.background = background
        self.education = education
        self.residence = residence
        self.family = family
        self.pets = pets
        self.personalityTraits = personalityTraits
        self.principles = principles
        self.skills = skills
        self.motivations = motivations
        self.weaknesses = weaknesses
        self.connections = connections
        self.quotes = quotes
        self.notes = notes
        self.isSampleCharacter = isSampleCharacter
    }

    var displayName: String {
        if !nickname.isEmpty && !fullName.isEmpty {
            return "\(fullName) (\(nickname))"
        }
        return fullName.isEmpty ? "Unnamed Character" : fullName
    }
}

// MARK: - Character Library Manager

class CharacterLibrary {
    static let shared = CharacterLibrary()

    private(set) var characters: [CharacterProfile] = []

    private init() {
        loadCharacters()
    }

    private var libraryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("QuillPilot", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        return appFolder.appendingPathComponent("CharacterLibrary.json")
    }

    func loadCharacters() {
        do {
            let data = try Data(contentsOf: libraryURL)
            let decoded = try JSONDecoder().decode([CharacterProfile].self, from: data)
            if decoded.isEmpty {
                // Seed with samples when the persisted library is empty
                characters = createSampleCharacters()
                saveCharacters()
            } else {
                characters = decoded
            }
        } catch {
            // If no saved characters, load sample characters
            characters = createSampleCharacters()
            saveCharacters()
        }
    }

    func saveCharacters() {
        do {
            let data = try JSONEncoder().encode(characters)
            try data.write(to: libraryURL)
        } catch {
            // Error saving, silent failure
        }
    }

    func addCharacter(_ character: CharacterProfile) {
        characters.insert(character, at: 0) // Insert at beginning
        saveCharacters()
        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }

    func updateCharacter(_ character: CharacterProfile) {
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters[index] = character
            saveCharacters()
            NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
        }
    }

    func deleteCharacter(_ character: CharacterProfile) {
        characters.removeAll { $0.id == character.id }
        saveCharacters()
        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }

    func createNewCharacter() -> CharacterProfile {
        return CharacterProfile(
            fullName: "",
            role: .supporting,
            isSampleCharacter: false
        )
    }

    private func createSampleCharacters() -> [CharacterProfile] {
        return [
            CharacterProfile(
                fullName: "Alex Ross Applegate",
                nickname: "Alex",
                role: .protagonist,
                age: "Mid-20s",
                occupation: "Operative / Contractor",
                appearance: "Athletic build, alert eyes, moves with practiced grace. Dresses practically—capable of blending in or standing out as needed.",
                background: """
Alex grew up on a sprawling Virginia estate, raised by a father whose old-money wealth masked a lifetime of intelligence work. After his parents were killed in what officials called a "random accident," Alex discovered the truth: his father was a legendary CIA operative, and the family's enemies had finally caught up with them.

Inheriting his father's network, fortune, and enemies, Alex was recruited into a shadowy private intelligence firm. Now he operates in the gray zone between nations—taking contracts that governments can't officially sanction, protecting those who can't protect themselves, and hunting the people who destroyed his family.
""",
                education: "Private tutors, elite preparatory academies, Ivy League degree in International Relations. Supplemented by intensive training in tradecraft, combat, and languages.",
                residence: "Primary residence in Georgetown; maintains safehouses internationally",
                family: """
Father (deceased): Legendary CIA operative, killed when Alex was young
Mother (deceased): Socialite and covert asset, killed alongside father
Grandfather: Retired intelligence director, occasional mentor and contact
""",
                pets: "A German Shepherd named Shadow—trained protection dog and loyal companion",
                personalityTraits: [
                    "Calculating but not cold",
                    "Loyal to those who earn it",
                    "Haunted by survivor's guilt",
                    "Dry wit under pressure",
                    "Struggles with trust"
                ],
                principles: [
                    "Never betray a source",
                    "Protect the innocent, even at personal cost",
                    "Everyone lies—find out why",
                    "Violence is a tool, not a solution",
                    "The mission comes first, but the team comes close second",
                    "Some secrets are worth dying for"
                ],
                skills: [
                    "Firearms: Expert marksman, particularly with pistols and precision rifles",
                    "Explosives: Trained in demolitions and IED detection",
                    "Tradecraft: Surveillance, counter-surveillance, dead drops, clandestine communications",
                    "Hand-to-Hand: Krav Maga, Brazilian Jiu-Jitsu",
                    "Languages: English, Russian, Arabic, Mandarin",
                    "Technical: Hacking, lock-picking, document forgery"
                ],
                motivations: "Seeking justice for his parents' murder while protecting others from similar fates. Driven by a need to find meaning in the violence he's trained for.",
                weaknesses: "Tendency toward isolation. Struggles to form lasting relationships. Sometimes takes unnecessary risks to prove something to himself.",
                connections: "Network of intelligence contacts, underworld informants, and former operatives. Maintains complicated relationship with official agencies.",
                quotes: [
                    "Trust is earned in drops and lost in floods.",
                    "Everyone's got a price. The trick is knowing what currency they deal in.",
                    "I don't believe in coincidences. I believe in enemies who are patient."
                ],
                notes: "Primary protagonist. Arc involves learning to trust again while uncovering conspiracy behind parents' deaths.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Viktor Mikhailovich Kurgan",
                nickname: "The Ghost",
                role: .antagonist,
                age: "38",
                occupation: "Freelance Assassin / Former FSB Agent",
                appearance: "Tall and lean with sharp Slavic features. Gray-blue eyes that seem to look through people rather than at them. A thin scar runs from his left temple to jaw. Moves with unsettling stillness—never fidgets, rarely blinks.",
                background: """
Born in the industrial wastelands of Norilsk, Siberia, Viktor learned survival before he learned to read. His father, a prison guard, taught him that power comes from being the one who isn't afraid. His mother died of lung disease when he was seven.

Recruited into FSB's wetwork division at nineteen, Viktor quickly earned a reputation for efficiency and emotional detachment. After a operation in Chechnya went wrong—leaving him the sole survivor—he was officially "killed in action." In reality, he'd been burned by his own agency and left for dead.

Now he works for whoever pays, but his real agenda is personal: hunting down the handlers who betrayed him while building the resources to one day destroy the organization that made him.
""",
                education: "Soviet-era military academy. FSB special operations training. Self-educated in chemistry, psychology, and languages.",
                residence: "No fixed address. Maintains a network of bolt-holes across Europe and Asia.",
                family: """
Father: Former prison guard, deceased (Viktor killed him at age 16 in self-defense)
Mother: Deceased from respiratory illness
No known siblings or children
""",
                pets: "None. \"Attachments are vulnerabilities.\"",
                personalityTraits: [
                    "Emotionally detached",
                    "Highly intelligent",
                    "Patient to the point of obsession",
                    "Paradoxically honest—never lies when the truth will hurt more",
                    "Capable of mimicking warmth but doesn't feel it"
                ],
                principles: [
                    "Emotion is weakness; eliminate it",
                    "Everyone betrays eventually—strike first",
                    "Pain is information",
                    "Leave no witnesses, but always leave a message",
                    "The job is never personal—until it is"
                ],
                skills: [
                    "Assassination: Poisons, garrotes, sniper, close-quarters",
                    "Infiltration: Social engineering, disguise, impersonation",
                    "Interrogation: Physical and psychological techniques",
                    "Combat: Sambo, Systema, knife fighting",
                    "Languages: Russian, English, German, Turkish, Arabic",
                    "Surveillance: Counter-intelligence, electronic warfare"
                ],
                motivations: "Revenge against the FSB handlers who burned him. Accumulating enough power and resources to feel truly safe for the first time in his life.",
                weaknesses: "Inability to understand genuine human connection. Obsessive need for control. Underestimates opponents who act irrationally or emotionally.",
                connections: "Network of criminal contacts, corrupt officials, and intelligence assets he's cultivated or blackmailed. No friends—only assets.",
                quotes: [
                    "I don't enjoy killing. I don't dislike it either. It's simply what I do.",
                    "You think you're the hero of this story? There are no heroes. Only survivors.",
                    "The difference between us? I know exactly what I am."
                ],
                notes: "Primary antagonist. Mirror to Alex—both made by violence, but Viktor embraced the darkness while Alex fights against it.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Raymond Quinn",
                nickname: "The Architect",
                role: .supporting,
                age: "90",
                occupation: "Global Philanthropist, Business Tycoon, Founder of The CoOp",
                appearance: "Distinguished elderly gentleman with sharp, thoughtful eyes that belie his age. Silver-haired, impeccably dressed, moves with the quiet confidence of someone who has shaped history.",
                background: """
A titan in the world of business, Raymond Quinn's name is synonymous with success and philanthropy. His business acumen, coupled with a keen strategic mind, has allowed him to amass a formidable fortune. As the driving force behind The CoOp and architect of C.H.E.S.S., his influence spans far beyond the boardroom.

At 15, Raymond invented Three-Dimensional Chess—three transparent stacked boards where pieces could move vertically between levels, played by three players simultaneously. This revolutionary game demonstrated his gift for multi-variable decision-making and probabilistic reasoning, skills that would define his career.

Deeply rooted in his values, Raymond believes in wielding his affluence and influence for the greater good. To him, wealth is not merely an asset but a tool to reshape the world, promoting democratic values, fairness, and equality.
""",
                education: "Child prodigy, self-educated in advanced strategy and game theory. Built vast business empire through strategic brilliance.",
                residence: "Multiple estates globally, primary residence undisclosed",
                family: """
Wife: Irina Quinn (deceased)
Daughter: Anya
Granddaughter: Dr. Cassandra Quinn
""",
                pets: "None",
                personalityTraits: [
                    "Visionary strategist",
                    "Reserved and thoughtful",
                    "Philanthropic at heart",
                    "Master of long-term planning",
                    "Deeply family-oriented"
                ],
                principles: [
                    "Wealth comes with responsibility to effect positive change",
                    "Democracy must be actively protected",
                    "Strategic patience over hasty action",
                    "Family bonds are sacred",
                    "Power should serve the greater good"
                ],
                skills: [
                    "Three-Dimensional Chess mastery",
                    "Multi-variable decision-making",
                    "Probabilistic reasoning",
                    "Global business strategy",
                    "Intelligence network coordination",
                    "Political influence"
                ],
                motivations: "Genuine desire to make the world better. Believes democracy must be protected through both public philanthropy and covert operations via The CoOp and C.H.E.S.S.",
                weaknesses: "Advanced age. Tendency to see the world as a chess game where people are pieces. The very organization he built (C.H.E.S.S.) shows signs of the same hubris that destroyed its predecessor.",
                connections: "Vast network of business leaders, politicians, and intelligence operatives worldwide. Founder of The CoOp. Secret architect of C.H.E.S.S. Major financial backer of democratic causes.",
                quotes: [
                    "In chess, as in life, victory belongs to those who think three moves ahead.",
                    "Wealth without purpose is merely numbers on a ledger.",
                    "Democracy is not a spectator sport."
                ],
                notes: "Key patron and strategist. His legacy includes both The CoOp and the shadowy C.H.E.S.S. organization. Complex figure—philanthropist and puppet master.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Dr. Cassandra Quinn",
                nickname: "Cassie",
                role: .supporting,
                age: "Early 30s",
                occupation: "Neuroscientist, Researcher",
                appearance: "Intelligent eyes behind designer glasses, professional but approachable demeanor. Carries herself with quiet confidence earned through academic achievement.",
                background: """
Granddaughter of Raymond Quinn, Cassie grew up surrounded by wealth and influence but chose to forge her own path through science. While her grandfather plays chess with nations, she explores the intricate game board of the human mind.

Her relationship with Raymond is profound—she represents the family connection that keeps him grounded amid his vast global machinations. To him, she embodies the future he's fighting to protect.
""",
                education: "Ph.D. in Neuroscience from top-tier university. Published researcher in cognitive science.",
                residence: "Lives independently, maintains close relationship with grandfather",
                family: """
Grandfather: Raymond Quinn
Mother: Anya Quinn
""",
                pets: "Unknown",
                personalityTraits: [
                    "Brilliant and analytical",
                    "Independent-minded",
                    "Compassionate scientist",
                    "Bridge between worlds",
                    "Grounded despite privilege"
                ],
                principles: [
                    "Science should serve humanity",
                    "Family loyalty matters",
                    "Independence through achievement",
                    "Ethics guide research",
                    "Knowledge is power"
                ],
                skills: [
                    "Neuroscience research",
                    "Data analysis",
                    "Scientific methodology",
                    "Academic writing",
                    "Public speaking"
                ],
                motivations: "Advancing human understanding of the brain. Maintaining family bonds while establishing own identity. May be unaware of the full extent of her grandfather's covert operations.",
                weaknesses: "Potential target due to family connection. Possible naivety about grandfather's darker activities. Could be leveraged against Raymond.",
                connections: "Academic community. Family connection to Raymond Quinn and his vast network.",
                quotes: [],
                notes: "Represents Raymond's humanity and what he fights to protect. Potential vulnerability and conscience for the Quinn family legacy.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Markus Kessler",
                nickname: "",
                role: .antagonist,
                age: "Early 40s",
                occupation: "US Senator",
                appearance: "Charismatic and well-groomed, with an unsettling intensity in his eyes. Commands attention in any room through presence and calculated charm.",
                background: """
Markus Kessler is the enigmatic and formidable antagonist who operates behind a veil of secrecy. A man of considerable intellect and ruthless determination, he uses his position as US Senator to advance his own radical agenda.

Kessler's motivations are rooted in a radical ideology that threatens the very foundations of democracy. He believes society needs a radical shift, and he's willing to use extreme means—including violence and subversion—to achieve his goals. He envisions a "New Order" that would centralize power, control information, implement surveillance, and eliminate dissent.
""",
                education: "Unknown, but clearly well-educated and politically sophisticated",
                residence: "Washington D.C. and undisclosed locations",
                family: "Unknown",
                pets: "None",
                personalityTraits: [
                    "Charismatic and manipulative",
                    "Cold and calculating",
                    "Obsessive about ideology",
                    "Meticulous planner",
                    "Dangerously patient"
                ],
                principles: [
                    "Centralized power brings order",
                    "The end justifies any means",
                    "Emotion is weakness to be exploited",
                    "Control information, control society",
                    "Democracy is inefficient and must be replaced"
                ],
                skills: [
                    "Political manipulation",
                    "Strategic planning",
                    "Propaganda and disinformation",
                    "Building shadow networks",
                    "Leveraging institutional power",
                    "Concealing true intentions"
                ],
                motivations: "Implementing his vision of a 'New Order'—centralized authoritarian control disguised as reform. Believes current democratic system is too fractured and must be replaced.",
                weaknesses: "Obsession with control. Fanatical certainty in his ideology. Underestimates opponents who genuinely believe in democracy. His very certainty makes him predictable.",
                connections: "Network of extremist allies embedded in government, military, and private sector. As US Senator, has significant political clout and insider access.",
                quotes: [],
                notes: "Primary political antagonist. Operates from within the system to destroy it. His dual role as Senator adds complexity—legitimate power used for illegitimate ends. Dark mirror to Raymond Quinn's use of wealth and influence.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Victoria Caldwell",
                nickname: "",
                role: .antagonist,
                age: "Early 50s",
                occupation: "Business Tycoon, Political Influencer",
                appearance: "Polished and powerful, radiates wealth and confidence. Every detail of her appearance is calculated to project success and control.",
                background: """
Victoria Caldwell represents the antithesis of Raymond Quinn. While Quinn uses his wealth to champion democratic causes, Caldwell wields her fortune to advance her own interests through ruthless business practices and political manipulation.

She views the world as a competitive arena where only the strong survive. Self-preservation and the pursuit of power drive her every move. To Caldwell, personal success is the only measure of worth, and she has no qualms about undermining democratic institutions for her benefit.
""",
                education: "Elite business education, though exact details kept private",
                residence: "Multiple luxury properties, primary residence undisclosed",
                family: "Estranged from family, if any exist",
                pets: "None—views attachments as weakness",
                personalityTraits: [
                    "Ruthlessly ambitious",
                    "Self-centered and mercenary",
                    "Machiavellian strategist",
                    "Secretive operator",
                    "Emotionally detached"
                ],
                principles: [
                    "Power is the ultimate goal",
                    "Personal gain justifies any action",
                    "Weakness deserves no sympathy",
                    "Rules exist to be exploited",
                    "Success requires sacrificing others"
                ],
                skills: [
                    "Corporate manipulation",
                    "Political influence campaigns",
                    "Shadow dealing",
                    "Alliance building for personal gain",
                    "Exploiting legal loopholes",
                    "Operating behind the scenes"
                ],
                motivations: "Accumulating power and wealth. Maintaining her position at the top of the hierarchy. Views life as zero-sum competition where she must win at others' expense.",
                weaknesses: "Complete lack of empathy makes her predictable. No genuine allies—everyone is a tool or threat. Her selfishness creates enemies. Cannot understand sacrifice for principles.",
                connections: "Vast business network built on mutual exploitation. Political connections purchased through money and leverage. No real friends, only assets.",
                quotes: [],
                notes: "Antagonist through greed rather than ideology. Foil to Raymond Quinn—shows the dark side of wealth and influence. Her pursuit of power places her against the protagonists who protect democracy.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Maggie Thornton",
                nickname: "",
                role: .minor,
                age: "40s",
                occupation: "Member of Congress, Social Media Influencer",
                appearance: "Deliberately cultivates controversial public image. Dresses to provoke attention and reinforce outsider status.",
                background: """
Maggie Thornton is a controversial political figure who gained national attention for promoting conspiracy theories and inflammatory rhetoric. Member of the Freedom Party, she uses social media to build a fervent base of supporters.

Removed from committee roles for sharing inflammatory content targeting religious and ethnic groups, she nonetheless maintains her seat and remains popular among her base. Her political career exists at the intersection of genuine grievance politics and dangerous disinformation.
""",
                education: "Unknown, but uses anti-elite rhetoric as political weapon",
                residence: "Her congressional district",
                family: "Strained relationship with family due to controversial positions",
                pets: "Unknown",
                personalityTraits: [
                    "Charismatic provocateur",
                    "Unfiltered and impulsive",
                    "Social media savvy",
                    "Attracts marginalized supporters",
                    "Thrives on controversy"
                ],
                principles: [
                    "Distrust of 'Deep State' and institutions",
                    "Health freedom over scientific consensus",
                    "Big government stifles growth",
                    "Speaking truth as she sees it",
                    "Representing the unheard"
                ],
                skills: [
                    "Social media manipulation",
                    "Rallying disaffected voters",
                    "Generating media attention",
                    "Avoiding consequences",
                    "Inflammatory rhetoric"
                ],
                motivations: "Attention and influence. Genuinely believes in conspiracy theories she promotes. Sees herself as truth-teller fighting corrupt system.",
                weaknesses: "Promotes dangerous misinformation. Lack of tact alienates potential allies. Inflammatory rhetoric limits effectiveness. Eventually faces censure and career threats.",
                connections: "Online supporter base. Tenuous relationships within her own party. Social media networks that amplify her message.",
                quotes: [],
                notes: "Minor antagonist through dangerous misinformation. Character explores modern political polarization and conspiracy theory culture. At crossroads—double down or moderate to save career.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Allison Matthews",
                nickname: "",
                role: .supporting,
                age: "Late 20s",
                occupation: "Unknown",
                appearance: "Unknown",
                background: """
Allison is Alex's anchor to normalcy in his otherwise clandestine life. Their relationship provides him with emotional connection and stability, though he must keep details of his work secret to protect her safety.

She represents the ordinary world Alex fights to protect, and the personal sacrifices required by his covert operations.
""",
                education: "Unknown",
                residence: "Unknown",
                family: "Unknown",
                pets: "Unknown",
                personalityTraits: [
                    "Understanding",
                    "Patient with Alex's secrets",
                    "Emotionally grounded",
                    "Represents normalcy"
                ],
                principles: [],
                skills: [],
                motivations: "Relationship with Alex. Living normal life despite his mysterious career.",
                weaknesses: "Potential target due to relationship with Alex. Unaware of true dangers surrounding her.",
                connections: "Romantic relationship with Alex Ross.",
                quotes: [],
                notes: "Supporting character. Represents what Alex protects and what he sacrifices for his work. Humanizes the protagonist.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Emily Thompson",
                nickname: "",
                role: .supporting,
                age: "Unknown",
                occupation: "Unknown",
                appearance: "Unknown",
                background: "Limited information available. Supporting character in Alex's world.",
                education: "Unknown",
                residence: "Unknown",
                family: "Unknown",
                pets: "Unknown",
                personalityTraits: [],
                principles: [],
                skills: [],
                motivations: "Unknown",
                weaknesses: "Unknown",
                connections: "Connected to Alex Ross's operations or personal life",
                quotes: [],
                notes: "Supporting character. More detail needed from source material.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Max",
                nickname: "The Shadow",
                role: .supporting,
                age: "5 years old",
                occupation: "Belgian Malinois, Alex's working dog and companion",
                appearance: "Belgian Malinois with keen, alert eyes. Athletic build maintained in peak condition. Wears specialized collar with surveillance equipment.",
                background: """
Max was born into a lineage of working dogs known for intelligence, agility, and strong work ethic. His exceptional traits made him ideal for specialized training in covert operations.

During puppyhood, Max formed a strong bond with Alex, establishing trust and communication critical to their work. His training intensified as he grew, encompassing advanced obedience, scent detection, and agility training through simulated mission scenarios.

Max is not just a loyal companion—he's an indispensable asset equipped with specialized technology integrated into his collar.
""",
                education: "Specialized training for covert operations: obedience, tracking, scent detection, agility, working under pressure",
                residence: "Lives with Alex Ross",
                family: "Bred from lineage of working dogs",
                pets: "N/A - Max IS the pet",
                personalityTraits: [
                    "Fiercely loyal and protective",
                    "High energy and driven",
                    "Highly intelligent and trainable",
                    "Alert and perceptive",
                    "Team-oriented"
                ],
                principles: [
                    "Protect Alex at all costs",
                    "Follow commands with precision",
                    "Stay alert to threats",
                    "Work as part of the team"
                ],
                skills: [
                    "Advanced obedience",
                    "Scent tracking and detection",
                    "Agility and physical conditioning",
                    "Working under pressure",
                    "Threat detection and alert",
                    "Teamwork in mission scenarios"
                ],
                motivations: "Loyalty to Alex. Drive to work and be useful. Innate protective instincts.",
                weaknesses: "Dog vulnerabilities—can be targeted to get to Alex. Reliant on Alex for direction in complex situations.",
                connections: "Primary bond with Alex Ross. Part of Alex's operational team.",
                quotes: [],
                notes: """
Supporting character and tactical asset. Equipped with Collar-Mounted Surveillance and Reconnaissance Unit (CSRU) featuring:
- Micro camera with real-time streaming
- Audio recorder and microphone
- GPS tracker
- Environmental sensors (temperature, humidity, radiation)
- Night vision and infrared
- Two-way communication
- Biometric monitoring
- Remote control capabilities
- Encrypted data transmission
- Long battery life

Max transforms Alex into a two-member reconnaissance team.
""",
                isSampleCharacter: true
            )
        ]
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let characterLibraryDidChange = Notification.Name("characterLibraryDidChange")
}
