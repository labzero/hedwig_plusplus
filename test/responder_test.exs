defmodule ResponderTest do
  use ExUnit.Case
  use Hedwig.RobotCase

  alias HedwigPlusPlus.Responder.{ScoreMessage, Score, Scoreboard}

  setup_all do
    data = %{
      "michi" => %Score{score: -10, reasons: %{"breaking the internet" => -10}},
      "brien" => %Score{score: 4, reasons: %{}},
      "rob" => %Score{score: 7, reasons: %{}}
    }
    %{data: data}
  end
  
  describe "ScoreMessage" do
    test "score message is created with default score of 0" do
      message = ScoreMessage.new("michi")
      assert message.score == 0
    end

    test "score message properly inflects the verb to be when the amount is 1" do
      message = %ScoreMessage{name: "michi", score: 1, reason: "stuff", increment: 1}
      assert String.contains?(ScoreMessage.to_string(message), " is for ")
    end

    test "score message properly inflects the verb to be when amount is > 1" do
      message = %ScoreMessage{name: "michi", score: 10, reason: "stuff", increment: 10}
      assert String.contains?(ScoreMessage.to_string(message), " are for ")
    end

    test "score message does not contain attribution when there is no reason" do
      message = %ScoreMessage{name: "michi", score: 10, increment: 10}
      refute String.contains?(ScoreMessage.to_string(message), "of which")
    end

    test "score message contains attribution when there is a reason" do
      message = %ScoreMessage{name: "michi", score: 10, reason: "stuff", increment: 10}
      assert String.contains?(ScoreMessage.to_string(message), "of which")
    end
  end

  describe "Score" do
    test "Score has a default score of 0" do
      assert %Score{}.score == 0
    end

    test "Score can be incremented" do
      assert Score.increment(%Score{}).score == 1
    end

    test "Score can be decremented" do
      assert Score.decrement(%Score{}).score == -1
    end

    test "a new reason can be added to a Score" do
      score = Score.add_reason(%Score{}, "stuff")
      assert Map.get(score.reasons, "stuff") == 1
    end

    test "multiple occurences of a reason are counted" do
      score =
        %Score{}
        |> Score.add_reason("stuff")
        |> Score.add_reason("stuff")
      assert Map.get(score.reasons, "stuff") == 2 
    end 
    
    test "best reason will give you the reson with the most points" do
      score =
        %Score{}
        |> Score.add_reason("reason 1")
        |> Score.add_reason("reason 2")
        |> Score.add_reason("reason 3")
        |> Score.add_reason("reason 3")
      assert Score.best_reason(score) == {"reason 3", 2}    
    end
  end

  describe "Scoreboard" do 
    
    test "top returns the highest scoring names", %{data: data} do
      top = [
        {"rob", %HedwigPlusPlus.Responder.Score{reasons: %{}, score: 7}},
        {"brien", %HedwigPlusPlus.Responder.Score{reasons: %{}, score: 4}}
      ]
      assert Scoreboard.top(data, 2) == top 
    end

    test "bottom returns the lowest scoring names", %{data: data} do
      bottom = [
        {"michi", %Score{reasons: %{"breaking the internet" => -10},score: -10}},
        {"brien", %Score{reasons: %{}, score: 4}}
      ]
      assert Scoreboard.bottom(data, 2) == bottom      
    end

    test "to_string returns an appropriate message when there is no data" do
      assert Scoreboard.to_string(%{}) == "No scores yet!"
    end

    test "to_string returns a line for each name on the scoreboard", %{data: data} do
      assert (Scoreboard.to_string(data) |> String.split("\n") |> Enum.count) == 3 
    end

  end

  describe "Responder" do

    setup do
      brain = HedwigBrain.brain
      lobe = brain.get_lobe("plusplus")
      data = %{
        "michi" => %Score{score: -10, reasons: %{"breaking the internet" => -10}},
        "brien" => %Score{score: 4, reasons: %{}},
        "rob" => %Score{score: 7, reasons: %{}}
      }
      Enum.each(data, fn {k, v} -> brain.put(lobe, k, v) end)
      :ok
    end

    @tag start_robot: true, name: "clippy", responders: [{HedwigPlusPlus.Responder, []}]
    test "give points without a reason", %{adapter: adapter, msg: msg} do
      send adapter, {:message, %{msg | text: "brien ++"}} 
      assert_receive {:message, %{text: text}}, 1000
      assert String.contains?(text, "brien has 5 points")
    end

    @tag start_robot: true, name: "clippy", responders: [{HedwigPlusPlus.Responder, []}]
    test "give points with a reason", %{adapter: adapter, msg: msg} do
      send adapter, {:message, %{msg | text: "brien ++ for moving to Tucson"}} 
      assert_receive {:message, %{text: text}}, 1000
      assert String.contains?(text, "brien has 5 points, 1 of which is for moving to Tucson")
    end

    @tag start_robot: true, name: "clippy", responders: [{HedwigPlusPlus.Responder, []}]
    test "take away points without a reason", %{adapter: adapter, msg: msg} do
      send adapter, {:message, %{msg | text: "michi --"}} 
      assert_receive {:message, %{text: text}}, 1000
      assert String.contains?(text, "michi has -11 points")
    end

    @tag start_robot: true, name: "clippy", responders: [{HedwigPlusPlus.Responder, []}]
    test "take away points with a reason", %{adapter: adapter, msg: msg} do
      send adapter, {:message, %{msg | text: "michi -- for breaking the internet"}} 
      assert_receive {:message, %{text: text}}, 1000
      assert String.contains?(text, "michi has -11 points, -1 of which is for breaking the internet")
    end   

    @tag start_robot: true, name: "clippy", responders: [{HedwigPlusPlus.Responder, []}]
    test "score for", %{adapter: adapter, msg: msg} do
      send adapter, {:message, %{msg | text: "score for michi"}} 
      assert_receive {:message, %{text: text}}, 1000
      assert String.contains?(text, "michi has -10 points, -10 of which are for breaking the internet")
    end     

    @tag start_robot: true, name: "clippy", responders: [{HedwigPlusPlus.Responder, []}]
    test "top", %{adapter: adapter, msg: msg} do
      send adapter, {:message, %{msg | text: "top 2"}} 
      assert_receive {:message, %{text: text}}, 1000
      assert String.contains?(text, "1. rob: 7\n2. brien: 4")
    end

    @tag start_robot: true, name: "clippy", responders: [{HedwigPlusPlus.Responder, []}]
    test "bottom", %{adapter: adapter, msg: msg} do
      send adapter, {:message, %{msg | text: "bottom 2"}} 
      assert_receive {:message, %{text: text}}, 1000
      assert String.contains?(text, "1. michi: -10\n2. brien: 4") 
    end                        
  end
end