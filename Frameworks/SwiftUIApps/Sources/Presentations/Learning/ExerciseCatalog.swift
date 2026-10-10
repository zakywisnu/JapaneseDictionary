enum ExerciseCatalog {
    static let grammar: [PracticeExercise] = [
        blank("topic", "わたし（　）学生です。", ["は", "を", "に"], 0, "は marks the topic: 'As for me, I am a student.' It is pronounced wa as a particle."),
        blank("object", "パン（　）食べます。", ["に", "を", "で"], 1, "を marks what you eat. パンを食べます means 'I eat bread.'"),
        blank("destination", "学校（　）行きます。", ["を", "で", "に"], 2, "に marks the destination with 行きます: 'I go to school.' へ can also mark direction, but it isn't a choice here."),
        blank("location", "図書館（　）勉強します。", ["で", "に", "を"], 0, "で marks where an action takes place: 'I study at the library.'"),
        blank("possession", "これはわたし（　）本です。", ["は", "の", "を"], 1, "の connects the owner and the thing: わたしの本 means 'my book.'"),
        blank("also", "わたしは学生です。友だち（　）学生です。", ["を", "に", "も"], 2, "も means 'also.' The friend is also a student."),
        blank("question", "これはあなたのかばんです（　）。", ["か", "を", "の"], 0, "か at the end turns this polite statement into a question: 'Is this your bag?'"),
        blank("existence", "机の上に本が（　）。", ["います", "あります", "行きます"], 1, "あります describes the existence of an inanimate thing, such as a book. います is used for people and animals."),
        blank("living", "部屋に猫が（　）。", ["あります", "読みます", "います"], 2, "います describes the existence of a living thing: 'There is a cat in the room.'"),
        blank("time", "毎朝、七時（　）起きます。", ["に", "で", "を"], 0, "に marks a specific time: 七時に means 'at seven o'clock.'"),
        blank("past", "きのう、映画を（　）。", ["見ます", "見ました", "見ません"], 1, "きのう means 'yesterday.' 見ました is the polite past form: 'I watched a movie.'"),
        blank("negative", "Complete “I will not watch TV today”: 今日、テレビを（　）。", ["見ました", "見ます", "見ません"], 2, "見ません is the polite negative: 'I don't watch TV.' The prompt asks for the negative meaning, so the past and affirmative forms do not fit."),
        blank("request", "この本を読んで（　）。", ["ください", "でした", "あります"], 0, "A verb's て-form followed by ください makes a polite request: 'Please read this book.'"),
        blank("adjective", "この部屋は（　）です。", ["静かな", "静か", "静かに"], 1, "A な-adjective stands directly before です: 静かです. Before a noun it uses な, as in 静かな部屋."),
        blank("adjective-noun", "（　）本を読みます。", ["おもしろく", "おもしろいに", "おもしろい"], 2, "An い-adjective modifies a noun directly: おもしろい本 means 'an interesting book.'"),
        choice("invitation", "Which sentence invites someone to drink tea together?", ["お茶を飲みませんか。", "お茶を飲みました。", "お茶を飲みません。"], 0, "A polite negative question, 飲みませんか, can invite someone: 'Would you like to drink tea?' The other choices are a past statement and a negative statement."),
        choice("want", "Which sentence means 'I want to go to Japan'?", ["日本に行きました。", "日本に行きたいです。", "日本に行きません。"], 1, "The verb stem 行き plus たい expresses the speaker's wish: 行きたいです means 'I want to go.'"),
        choice("because", "What does 雨ですから、家にいます。 mean?", ["It rained at home.", "I go home when it rains.", "Because it is raining, I am staying at home."], 2, "から after a clause gives a reason. 雨です is the reason; 家にいます is the result.")
    ]

    static func blank(_ id: String, _ prompt: String, _ choices: [String], _ answer: Int, _ explanation: String) -> PracticeExercise {
        .init(id: id, kind: .fillBlank, prompt: prompt, choices: choices, correctIndex: answer, explanation: explanation)
    }
    static func choice(_ id: String, _ prompt: String, _ choices: [String], _ answer: Int, _ explanation: String) -> PracticeExercise {
        .init(id: id, kind: .choice, prompt: prompt, choices: choices, correctIndex: answer, explanation: explanation)
    }
}
