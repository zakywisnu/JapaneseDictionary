struct ReadingPassage: Identifiable {
    let id: String
    let title: String
    let text: String
    let reading: String
    let translation: String
    let vocabulary: [String]
    let questions: [PracticeExercise]
}

enum ReadingCatalog {
    static let passages: [ReadingPassage] = [
        .init(id: "morning", title: "A quiet morning",
              text: "毎朝、わたしは七時に起きます。朝ご飯はパンと卵です。お茶を飲んで、八時に学校へ行きます。",
              reading: "まいあさ、わたしはしちじにおきます。あさごはんはパンとたまごです。おちゃをのんで、はちじにがっこうへいきます。",
              translation: "Every morning, I get up at seven. Breakfast is bread and eggs. I drink tea and go to school at eight.",
              vocabulary: ["毎朝", "卵", "学校"], questions: [
                ExerciseCatalog.choice("morning-time", "When does the speaker get up?", ["At seven", "At eight", "At nine"], 0, "七時に起きます says that the speaker gets up at seven. Eight is the time for going to school."),
                ExerciseCatalog.choice("morning-food", "What does the speaker eat for breakfast?", ["Rice and fish", "Bread and eggs", "Only tea"], 1, "朝ご飯はパンと卵です names bread and eggs as breakfast.")]),
        .init(id: "library", title: "At the library",
              text: "土曜日、友だちと図書館へ行きました。わたしは日本語の本を読みました。友だちは宿題をしました。図書館は静かでした。",
              reading: "どようび、ともだちととしょかんへいきました。わたしはにほんごのほんをよみました。ともだちはしゅくだいをしました。としょかんはしずかでした。",
              translation: "On Saturday, I went to the library with a friend. I read a Japanese-language book. My friend did homework. The library was quiet.",
              vocabulary: ["土曜日", "図書館", "宿題"], questions: [
                ExerciseCatalog.choice("library-day", "On which day did they go to the library?", ["Monday", "Sunday", "Saturday"], 2, "The opening word 土曜日 means Saturday."),
                ExerciseCatalog.choice("library-friend", "What did the friend do?", ["Homework", "Read a newspaper", "Drink tea"], 0, "友だちは宿題をしました says that the friend did homework.")]),
        .init(id: "shopping", title: "Buying fruit",
              text: "今日は母と店へ行きます。りんごを三つ買います。バナナも買います。家で果物を食べます。",
              reading: "きょうはははとみせへいきます。りんごをみっつかいます。バナナもかいます。いえでくだものをたべます。",
              translation: "Today I am going to the shop with my mother. We will buy three apples. We will also buy bananas. We will eat fruit at home.",
              vocabulary: ["母", "店", "果物"], questions: [
                ExerciseCatalog.choice("shopping-count", "How many apples will they buy?", ["Two", "Three", "Four"], 1, "りんごを三つ買います says they will buy three apples. 三つ is read みっつ."),
                ExerciseCatalog.choice("shopping-place", "Where will they eat the fruit?", ["At the shop", "At school", "At home"], 2, "家で果物を食べます gives the location: at home.")]),
        .init(id: "cat", title: "The cat and the chair",
              text: "わたしの家に小さい猫がいます。名前はモモです。今、モモは椅子の下にいます。椅子の上には本があります。",
              reading: "わたしのいえにちいさいねこがいます。なまえはモモです。いま、モモはいすのしたにいます。いすのうえにはほんがあります。",
              translation: "There is a small cat in my home. Its name is Momo. Right now, Momo is under the chair. There is a book on the chair.",
              vocabulary: ["猫", "椅子", "名前"], questions: [
                ExerciseCatalog.choice("cat-location", "Where is Momo now?", ["Under the chair", "On the chair", "Under a book"], 0, "椅子の下にいます places Momo under the chair. The book is on it."),
                ExerciseCatalog.choice("cat-name", "What is the cat's name?", ["Mimi", "Momo", "Hana"], 1, "名前はモモです explicitly gives the name Momo.")]),
        .init(id: "rain", title: "A rainy Sunday",
              text: "日曜日は雨でした。公園へ行きませんでした。家で音楽を聞きました。午後、妹と映画を見ました。",
              reading: "にちようびはあめでした。こうえんへいきませんでした。いえでおんがくをききました。ごご、いもうととえいがをみました。",
              translation: "It rained on Sunday. I did not go to the park. I listened to music at home. In the afternoon, I watched a movie with my younger sister.",
              vocabulary: ["雨", "公園", "映画"], questions: [
                ExerciseCatalog.choice("rain-park", "Did the speaker go to the park?", ["Yes, in the morning", "Yes, in the afternoon", "No"], 2, "行きませんでした is a polite past negative: the speaker did not go."),
                ExerciseCatalog.choice("rain-company", "Who watched the movie with the speaker?", ["Their younger sister", "Their mother", "Their friend"], 0, "妹と means 'with my younger sister.'")]),
        .init(id: "train", title: "Meeting a friend",
              text: "明日、友だちに会います。電車で駅へ行きます。十時に駅の前で会います。それから、一緒に昼ご飯を食べます。",
              reading: "あした、ともだちにあいます。でんしゃでえきへいきます。じゅうじにえきのまえであいます。それから、いっしょにひるごはんをたべます。",
              translation: "Tomorrow, I will meet a friend. I will go to the station by train. We will meet in front of the station at ten. After that, we will eat lunch together.",
              vocabulary: ["明日", "電車", "駅"], questions: [
                ExerciseCatalog.choice("train-transport", "How will the speaker get to the station?", ["By bus", "By train", "On foot"], 1, "電車で describes the means of travel: by train."),
                ExerciseCatalog.choice("train-plan", "What will they do after meeting?", ["Study at the library", "Watch a movie", "Eat lunch together"], 2, "それから means 'after that.' The next sentence says they will eat lunch together.")])
    ]
}
