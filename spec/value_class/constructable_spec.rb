require 'spec_helper'

class TestBikeTire
  include ValueClass::Constructable

  value_attr :diameter, description: "The diameter in inches"
  value_attr :tred,     description: "The tred on the tire"
end

class TestBikeSeat
  include ValueClass::Constructable

  value_attr :size, description: "The size of the bike seat in inches"
  value_attr :color
end

class TestBicycle
  include ValueClass::Constructable

  value_description "For riding around town"
  value_attr :speeds
  value_attr :color, default: :orange
  value_attr :seat, class_name: 'TestBikeSeat'

  value_list_attr :riders, insert_method: :add_rider
  value_list_attr :tires, insert_method: :tire, class_name: 'TestBikeTire'
end

class TestHeadlight
  include ValueClass::Constructable
  value_attr :lumens, required: true
end


describe ValueClass::Constructable do
  context "configurable" do
    it "supports constructing instances from config" do
      bike = TestBicycle.config do |bicycle|
        bicycle.speeds = 10
        bicycle.color = :blue
      end

      expect(bike.speeds).to eq(10)
      expect(bike.color).to eq(:blue)
    end

    it "supports nested config" do
      bike = TestBicycle.config do |bicycle|
        bicycle.speeds = 10
        bicycle.color = :blue
        bicycle.seat do |seat|
          seat.color = :green
          seat.size  = :large
        end
      end

      expect(bike.speeds).to eq(10)
      expect(bike.color).to eq(:blue)
      expect(bike.seat.color).to eq(:green)
      expect(bike.seat.size).to eq(:large)
    end

    it "supports accessing variables from outside the scope" do
      seat_color = :magenta

      bike = TestBicycle.config do |bicycle|
        bicycle.seat do |seat|
          seat.color = seat_color
        end
      end

      expect(bike.seat.color).to eq(:magenta)
    end

    it "supports assigning hashes to typed attributes" do
      bike = TestBicycle.config do |bicycle|
        bicycle.seat = { color: :blue }
      end

      expect(bike.seat.color).to eq(:blue)
    end

    it "supports generating a description" do
      expected_description  = <<-EOF.gsub(/^ {8}/, '')
        TestBicycle: For riding around town
          attributes:
            speeds
            color
            seat
            riders
            tires
      EOF

      expect(TestBicycle.config_help).to eq(expected_description)
    end


    it "supports specifying a default attribute" do
      bike = TestBicycle.config { |_| }

      expect(bike.color).to eq(:orange)
    end

    it "be able to construct the class with a hash" do
      bike = TestBicycle.new(speeds: 10, color: :gold)
      expect(bike.color).to eq(:gold)
    end

    context "lists" do
      it "should be able to directly assign lists" do
        bike = TestBicycle.config do |bicycle|
          bicycle.riders = [:bob, :victor]
        end

        expect(bike.riders).to eq([:bob, :victor])
      end

      it "should be able to configure using the add method" do
        bike = TestBicycle.config do |bicycle|
          bicycle.add_rider :bob
          bicycle.add_rider :victor
        end

        expect(bike.riders).to eq([:bob, :victor])
      end

      it "should be able to use the add method to add nested classes" do
        bike = TestBicycle.config do |bicycle|
          bicycle.tire do |tire_config|
            tire_config.diameter = 40
            tire_config.tred = :mountain
          end

          bicycle.tire do |tire_config|
            tire_config.diameter = 50
            tire_config.tred = :slicks
          end
        end

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end

      it "be able to construct the class with a hash" do
        bike = TestBicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain}, {diameter: 50, tred: :slicks}] )

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end

      it "be able to assign a hash to the attribute during config" do
        bike = TestBicycle.config do |bicycle|
          bicycle.tires = [{ diameter: 40, tred: :mountain}, {diameter: 50, tred: :slicks}]
        end

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end

    end
  end

  context "validations" do
    it "should raise an exception if a required parameter is missing" do
      expect { TestHeadlight.new }.to  raise_error(ArgumentError, "must provide a value for lumens")

    end
  end
end

