require 'spec_helper'

describe "Bit matching" do
  subject { XkcdSkein.bit_wrongness(XkcdSkein.skein_hash(str)) }

  describe "NMAeykp3cpLe9hqwInS" do
    let(:str) { "NMAeykp3cpLe9hqwInS" }
    it        { should == 553 }
  end

  describe "6sGs9c8CT7tzbw" do
    let(:str) { "6sGs9c8CT7tzbw" }
    it        { should == 548 }
  end

  describe "jB7l9HNgEE2DRxL5txUkAUI" do
    let(:str) { "jB7l9HNgEE2DRxL5txUkAUI" }
    it        { should == 547 }
  end

  describe "qHWQM7i1N7gBmew60WF" do
    let(:str) { "qHWQM7i1N7gBmew60WF" }
    it        { should == 544 }
  end
end
