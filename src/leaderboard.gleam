import beach
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/string
import shore
import shore/key
import shore/style
import shore/ui

// MAIN

pub fn main() {
  let assert Ok(actor.Started(data: shared_model, ..)) = init_shared()
  let spec =
    shore.spec(
      init: fn() { init(shared_model) },
      update:,
      view:,
      exit: process.new_subject(),
      keybinds: shore.keybinds(
        exit: key.Char("q"),
        submit: key.Enter,
        focus_clear: key.Esc,
        focus_next: key.Tab,
        focus_prev: key.BackTab,
      ),
      redraw: shore.on_timer(16),
      // on_update has initial screen size wrong on launch
    )
  let config =
    beach.config(
      port: 2222,
      host_key_directory: ".",
      auth: beach.auth_anonymous(),
      on_connect: fn(connection, shore) {
        let info = connection
        process.send(shared_model, LoggedIn(shore, info.username))
        process.send(shore, shore.send(SetUsername(info.username)))
      },
      on_disconnect: fn(connection, shore) {
        let info = connection
        process.send(shared_model, LoggedOut(shore, info.username))
      },
      max_sessions: None,
    )
  let assert Ok(_) = beach.start(spec, config)
  process.sleep_forever()
}

// MODEL

type Model {
  Model(
    counter: Int,
    username: String,
    users: List(User),
    shared: process.Subject(SharedMsg),
  )
}

fn init(shared: process.Subject(SharedMsg)) -> #(Model, List(fn() -> Msg)) {
  let model = Model(counter: 0, username: "greg", users: [], shared:)
  let cmds = []
  #(model, cmds)
}

// Shared
type User {
  User(name: String, shore: process.Subject(shore.Event(Msg)))
}

type SharedModel {
  SharedModel(users: List(User))
}

type SharedMsg {
  LoggedIn(shore: process.Subject(shore.Event(Msg)), name: String)
  LoggedOut(shore: process.Subject(shore.Event(Msg)), name: String)
}

fn init_shared() -> Result(
  actor.Started(process.Subject(SharedMsg)),
  actor.StartError,
) {
  actor.new(SharedModel(users: []))
  |> actor.on_message(update_shared)
  |> actor.start
}

fn update_shared(
  state: SharedModel,
  msg: SharedMsg,
) -> actor.Next(SharedModel, SharedMsg) {
  case msg {
    LoggedIn(shore, name) -> {
      let user = User(name:, shore:)
      let SharedModel(users) = state
      let users = [user, ..users]
      list.each(users, fn(u) { actor.send(u.shore, shore.send(Sync(users))) })
      let state = SharedModel(users)
      io.println("Logged In: " <> name)
      actor.continue(state)
    }
    LoggedOut(shore, username) -> {
      let user = User(name: username, shore:)
      let SharedModel(users) = state
      // assumes this is unique, maybe when combine with score it will be?
      let users = list.filter(users, fn(auser) { auser.shore == user.shore })
      list.each(users, fn(u) { actor.send(u.shore, shore.send(Sync(users))) })
      let state = SharedModel(users)
      io.println("Logged Out: " <> username)
      actor.continue(state)
    }
  }
}

// UPDATE

type Msg {
  AddOne
  SetUsername(name: String)
  Sync(users: List(User))
}

fn update(model: Model, msg: Msg) -> #(Model, List(fn() -> Msg)) {
  case msg {
    AddOne -> {
      #(Model(..model, counter: model.counter + 1), [])
    }
    SetUsername(name) -> #(
      Model(..model, username: string.capitalise(name)),
      [],
    )
    Sync(users) -> #(Model(..model, users:), [])
  }
}

// VIEW

fn view(model: Model) -> shore.Node(Msg) {
  ui.box(
    [
      ui.text("Welcome " <> model.username <> "!")
        |> ui.align(style.Right, _),
      ui.br(),
      ui.text_wrapped("Your score: " <> int.to_string(model.counter)),
      ui.br(),
      ui.text("Leaderboard"),
      ui.br(),
      ui.col(
        model.users
        |> list.map(fn(user) { ui.text(user.name) }),
      ),
      ui.hr(),
      ui.row([
        ui.button("Press 'i'", key.Char("i"), AddOne),
        ui.text_styled(
          "  Press 'q' to quit  ",
          Some(style.Black),
          Some(style.Red),
        ),
      ]),
    ],
    Some("Gleaderboard"),
  )
}
