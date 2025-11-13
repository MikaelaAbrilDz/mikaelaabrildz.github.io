import gleam/dict.{type Dict}

pub fn get_projects() -> Dict(String, String) {
  dict.from_list([
    #("ravioli-ravioli", "<h1 id=\"Ravioli-Ravioli\">Ravioli, Ravioli</h1>\n<p id=\"mobile-images\"><img alt=\"Gif\" src=\"/kiss.gif\"></p>\n<ul>\n<li>\nA funny PC game with an emphasis on comedy.\n</li>\n<li>\nManagement of clients and cooking actions.\n</li>\n<li>\nSimple controls and easy gameplay.\n</li>\n<li>\nMade in Unity.\n</li>\n</ul>\n<h2 id=\"Play-it\">Play it!</h2>\n<p>A link to play will appear here soon.</p>\n"),
    #("the-flying-rocket", "<h1 id=\"The-Flying-Rocket\">The Flying Rocket</h1>\n<p id=\"mobile-images\"><img alt=\"Gif\" src=\"/Gif_Rocket_0.gif\"></p>\n<ul>\n<li>\nA twist on the classic spaceship arcade game, using force-based controls.\n</li>\n<li>\nDesigned to be a short experience with a steep learning curve for the controls.\n</li>\n<li>\nAdapted for both touchscreen and keyboard (A and D).\n</li>\n<li>\nMade in Unity.\n</li>\n</ul>\n<p class=\"play-button\"><a href=\"/Build-Rocket/index.html\" target=\"_blank\">PLAY</a></p>\n"),
    #("the-wizards-tower", "<h1 id=\"The-Wizard's-Tower\">The Wizard&#39;s Tower</h1>\n<p id=\"mobile-images\"><img alt=\"Gif\" src=\"/kiss.gif\"></p>\n<ul>\n<li>\n2D platformer\n</li>\n<li>\nMade in Unity.\n</li>\n</ul>\n<h2 id=\"Play-it\">Play it!</h2>\n<p>A link to play will appear here soon.</p>\n"),
  ])
}
