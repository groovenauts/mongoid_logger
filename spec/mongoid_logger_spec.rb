require 'spec_helper'

describe MongoidLogger do
  it 'should have a version number' do
    MongoidLogger::VERSION.should_not be_nil
  end

  it 'should do something useful' do
    false.should be_true
  end
end
