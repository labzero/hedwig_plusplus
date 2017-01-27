defmodule HedwigPlusPlus.Responder do
  @moduledoc """
   Give or take away points. Keeps track and even prints out graphs.#

  Configuration:
   Your bot must have a brain (https://github.com/labzero/hedwig_brain)

  Commands:
   <name>++
   <name>--
   hubot score <name>
   hubot top <amount>
   hubot bottom <amount>  
  """

  use Hedwig.Responder

  defmodule ScoreMessage do
    defstruct [:name, :score, :reason, :increment]

    def new(name) do
      %ScoreMessage{name: name, score: 0, reason: "", increment: 1}
    end

    def to_string(%ScoreMessage{reason: reason} = sm) when is_nil(reason) or reason == "" do
      score_string(sm)
    end

    def to_string(%ScoreMessage{} = sm) do
      verb = if abs(sm.increment) == 1, do: "is", else: "are"
      "#{score_string(sm)}, #{sm.increment} of which #{verb} for #{sm.reason}"
    end

    defp score_string(%ScoreMessage{name: name, score: score}) do
      noun = if abs(score) == 1, do: "point", else: "points"
      "#{name} has #{score} #{noun}"
    end    
  end

  defmodule Score do
    defstruct score: 0, reasons: %{}

    def new(score, delta) do
      %Score{score | score: score.score + delta}
    end

    def increment(score) do
      %Score{score| score: score.score + 1}
    end

    def decrement(score) do
      %Score{score | score: score.score - 1}
    end

    # no-op when no reason is provided
    def add_reason(score, reason) when is_nil(reason) or reason == "" do
      score
    end

    # add a reason to the map with an initial # of points of 1
    def add_reason(%Score{reasons: reasons} = score, reason, delta) do
      updater = fn val -> if val == nil, do: {val, delta}, else: {val, val + delta} end
      {_, updated_reasons} = Map.get_and_update(reasons, HedwigPlusPlus.Responder.Scoreboard.canonicalize(reason), updater)
      %Score{score | reasons: updated_reasons}      
    end

    # most recent reason to use when no reason is provided
    def random_reason(%Score{reasons: reasons}) when map_size(reasons) == 0 do
      :error
    end

    def random_reason(%Score{reasons: reasons}) do
      Enum.random(reasons)
    end

    def best_reason(%Score{reasons: reasons}) when map_size(reasons) == 0 do
      :error
    end

    def best_reason(%Score{reasons: reasons}) do
      [{k, v}] =          
        reasons
        |> Enum.sort_by(fn {_, v} -> v end)
        |> Enum.reverse
        |> Enum.take(1)
      {k, v}      
    end
  end

  defmodule Scoreboard do

    @lobe "plusplus"

    def data_for(name) do
      case brain.get(storage, canonicalize(name)) do
        nil -> %Score{}
        data -> data
      end
    end    

    def all do
      brain.all(storage)
    end

    def save(%Score{} = data, name) do
      brain.put(storage, name, data)
      data
    end

    def top(data, n) do
      data
      |> Enum.sort_by(&sorter/1)
      |> Enum.reverse
      |> Enum.take(n)
    end

    def bottom(data, n) do
      data
      |> Enum.sort_by(&sorter/1)
      |> Enum.take(n)      
    end  

    defp sorter({_, %Score{score: score}}), do: score      

    defp brain do
        HedwigBrain.brain
    end

    defp storage do
      brain.get_lobe(@lobe)
    end

    defp line({{name, %Score{score: score}}, index}) do
      "#{index + 1}. #{name}: #{score}"
    end

    def canonicalize(string) do
      string
      |> String.downcase
      |> String.trim
    end

    def to_string(data) when map_size(data) == 0 or is_nil(data), do: "No scores yet!"

    def to_string(data) do
      data
      |> Enum.with_index
      |> Enum.map(&line/1)
      |> Enum.join("\n")
    end
  end

  @usage """
   <name>++
   <name>--
   hubot score <name>
   hubot top <amount>
   hubot bottom <amount>     
  """

  hear ~r/^(?<name>(?:\S+\s*?)+)\s*(?<op>\+\+|--|—)(?:\s+(?:for|because|cause|cuz|as)\s+(?<reason>.+?)\s*)?$/ui, message do
    %{"name" => name, "op" => op, "reason" => reason} = message.matches
    delta = case op do
      "++" -> 1
      "--" -> -1
    end
    score = 
      Scoreboard.data_for(name)
      |> Score.new(delta)   
      |> Score.add_reason(reason, delta)
      |> Scoreboard.save(name)
    {message_reason, message_increment} = if reason == "" do
      case Score.random_reason(score) do
        :error -> {"", 0}
        data -> data
      end
    else      
      {reason, (if op == "++", do: 1, else: -1)}
    end    
    msg = %ScoreMessage{name: name, score: score.score, reason: message_reason, increment: message_increment}    
    send message, ScoreMessage.to_string(msg)
  end

  hear ~r/^score (for\s)?(?<name>.*)/i, message do
    name = message.matches["name"]
    data = Scoreboard.data_for(name)
    {message_reason, message_increment} = 
      case Score.best_reason(data) do
        :error -> {"", 0}
        best -> best
      end    
    msg = %ScoreMessage{name: name, score: data.score, reason: message_reason, increment: message_increment}
    send message, ScoreMessage.to_string(msg)
  end

  hear ~r/^top (?<num>\d+)/i, message do
    num = String.to_integer(message.matches["num"])    
    send message, Scoreboard.to_string(Scoreboard.top(Scoreboard.all, num))
  end

  hear ~r/^bottom (?<num>\d+)/i, message do
    num = String.to_integer(message.matches["num"])    
    send message, Scoreboard.to_string(Scoreboard.bottom(Scoreboard.all, num))
  end
end
