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
      // redraw: shore.on_timer(16),
      redraw: shore.on_update(),
      // on_update has issues for me
    )
  let config =
    beach.config(
      port: 2222,
      host_key_directory: ".",
      auth: beach.auth_anonymous(),
      on_connect: fn(connection, shore) {
        let info = connection
        process.send(shared_model, LoggedIn(shore, info.username))
        process.send(
          shore,
          shore.send(
            SetSelf(User(
              name: string.capitalise(info.username),
              score: 0,
              session: shore,
            )),
          ),
        )
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
  Model(users: List(User), myself: User, shared: process.Subject(SharedMsg))
}

fn init(shared: process.Subject(SharedMsg)) -> #(Model, List(fn() -> Msg)) {
  let model =
    Model(
      myself: User(name: "greg", score: 0, session: process.new_subject()),
      users: [],
      shared:,
    )
  let cmds = []
  #(model, cmds)
}

// Shared
type User {
  User(name: String, score: Int, session: process.Subject(shore.Event(Msg)))
}

type SharedModel {
  SharedModel(users: List(User))
}

type SharedMsg {
  LoggedIn(shore: process.Subject(shore.Event(Msg)), name: String)
  LoggedOut(shore: process.Subject(shore.Event(Msg)), name: String)
  UpdateScore(shore: process.Subject(shore.Event(Msg)), score: Int)
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
    LoggedIn(session, name) -> {
      let user = User(name: string.capitalise(name), session:, score: 0)
      let SharedModel(users) = state
      let users = [user, ..users]
      list.each(users, fn(u) { actor.send(u.session, shore.send(Sync(users))) })
      let state = SharedModel(users)
      io.println("Logged In: " <> name)
      actor.continue(state)
    }
    LoggedOut(session, username) -> {
      let user = User(name: username, session:, score: 0)
      let SharedModel(users) = state
      // assumes this is unique, maybe when combine with score it will be?
      let users =
        list.filter(users, fn(auser) { auser.session != user.session })
      list.each(users, fn(u) { actor.send(u.session, shore.send(Sync(users))) })
      let state = SharedModel(users)
      io.println("Logged Out: " <> username)
      actor.continue(state)
    }
    UpdateScore(session, score) -> {
      let state =
        list.map(state.users, fn(user) {
          case user.session == session {
            True -> {
              User(..user, score:)
            }
            False -> {
              user
            }
          }
        })
        |> list.sort(fn(a, b) { int.compare(b.score, a.score) })
        |> SharedModel
      list.each(state.users, fn(u) {
        actor.send(u.session, shore.send(Sync(state.users)))
      })
      actor.continue(state)
    }
  }
}

// UPDATE

type Msg {
  AddOne
  SetSelf(self: User)
  Sync(users: List(User))
}

fn update(model: Model, msg: Msg) -> #(Model, List(fn() -> Msg)) {
  case msg {
    AddOne -> {
      process.send(
        model.shared,
        UpdateScore(model.myself.session, model.myself.score + 1),
      )
      #(
        Model(
          ..model,
          myself: User(..model.myself, score: model.myself.score + 1),
        ),
        [],
      )
    }
    SetSelf(myself) -> #(Model(..model, myself:), [])
    Sync(users) -> {
      #(Model(..model, users:), [])
    }
  }
}

// VIEW

fn view(model: Model) -> shore.Node(Msg) {
  ui.box(
    [
      ui.text("Welcome " <> model.myself.name <> "!")
        |> ui.align(style.Right, _),
      ui.br(),
      ui.text_wrapped_styled(
        "Your score: " <> int.to_string(model.myself.score),
        Some(style.Green),
        None,
      ),
      ui.br(),
      ui.text("Leaderboard"),
      ui.br(),
      ui.col(
        model.users
        |> list.filter(fn(user) { user != model.myself })
        |> list.map(fn(user) {
          ui.text(user.name <> " -> " <> int.to_string(user.score))
        }),
      ),
      ui.hr(),
      ui.row([
        ui.button("Press 'i' to increase", key.Char("i"), AddOne),
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
