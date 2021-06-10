# OpticRed

To start your Phoenix server:

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `npm install` inside the `assets` directory
- Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## Game flow m,nlkk

1. Each teams `Secret Agent` recieves a random `Code` and types in one `Clue` for each number
2. When both `Secret Agents` have submitted their clues, the `Red Team's Clues` are first revealed and all players except the `Red Team's Secret Agent` discuss the clues. Whenever a team thinks they have solved the `Code`, they type it in and submit.
3. When both teams have submitted their `Guesses` the `Blue Team's Guess` is revealed first for dramatical effect. If they guessed right, they recieve a `Point`. Then the `Red Team's Guess` is revealed. If they are wrong, they lose a `Point`
4. Repeat from step 2, but change the order of the teams.
