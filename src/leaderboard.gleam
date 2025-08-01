import beach
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{Some}
import shore
import shore/key
import shore/layout
import shore/style
import shore/ui

// MAIN

pub fn main() {
  let exit = process.new_subject()
  let spec =
    shore.spec(
      init:,
      update:,
      view:,
      exit:,
      keybinds: shore.keybinds(
        exit: key.Char("q"),
        submit: key.Enter,
        focus_clear: key.Esc,
        focus_next: key.Tab,
        focus_prev: key.BackTab,
      ),
      redraw: shore.on_update(),
    )
  let config =
    beach.config(
      port: 2222,
      host_key_directory: ".",
      auth: beach.auth_anonymous(),
      on_connect: fn(_connection, _shore) { Nil },
      on_disconnect: fn(_connection, _shore) { Nil },
      max_sessions: Some(1000),
    )
  let assert Ok(_) = beach.start(spec, config)
  process.sleep_forever()
}

// MODEL

type Model {
  Model(counter: Int)
}

fn init() -> #(Model, List(fn() -> Msg)) {
  let model = Model(counter: 0)
  let cmds = []
  #(model, cmds)
}

// UPDATE

type Msg {
  Increment
  Decrement
  Quit
}

fn update(model: Model, msg: Msg) -> #(Model, List(fn() -> Msg)) {
  case msg {
    Increment -> #(Model(counter: model.counter + 1), [])
    Decrement -> #(Model(counter: model.counter - 1), [])
    Quit -> {
      io.print("I QUIT")
      #(model, [])
    }
  }
}

// VIEW

fn view(model: Model) -> shore.Node(Msg) {
  ui.col([
    ui.text(
      "keybinds

i: increment
d: decrement
q: quit
      ",
    ),
    ui.text(int.to_string(model.counter)),
    ui.input("Test Input: ", "", style.Fill, fn(_) { Increment }),
    ui.hr(),
    ui.col([
      ui.button("increment", key.Char("i"), Increment),
      ui.button("decrement", key.Char("d"), Decrement),
    ]),
  ])
  |> ui.align(style.Center, _)
  |> layout.center(style.Pct(100), style.Pct(100))
}
