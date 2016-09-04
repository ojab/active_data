# encoding: UTF-8
require 'spec_helper'

describe ActiveData::Model::Associations::EmbedsOne do
  before do
    stub_model(:author) do
      include ActiveData::Model::Lifecycle

      attribute :name, String
      validates :name, presence: true
    end

    stub_model(:book) do
      include ActiveData::Model::Persistence
      include ActiveData::Model::Associations

      attribute :title, String
      embeds_one :author
    end
  end

  let(:book) { Book.new }
  let(:association) { book.association(:author) }

  let(:existing_book) { Book.instantiate title: 'My Life', author: { 'name' => 'Johny' } }
  let(:existing_association) { existing_book.association(:author) }

  describe 'book#association' do
    specify { expect(association).to be_a described_class }
    specify { expect(association).to eq(book.association(:author)) }
  end

  describe '#build' do
    specify { expect(association.build).to be_a Author }
    specify { expect(association.build).not_to be_persisted }

    specify do
      expect { association.build(name: 'Fred') }
        .not_to change { book.read_attribute(:author) }
    end

    specify do
      expect { existing_association.build(name: 'Fred') }
        .not_to change { existing_book.read_attribute(:author) }
    end
  end

  describe '#create' do
    specify { expect(association.create).to be_a Author }
    specify { expect(association.create).not_to be_persisted }

    specify { expect(association.create(name: 'Fred')).to be_a Author }
    specify { expect(association.create(name: 'Fred')).to be_persisted }

    specify do
      expect { association.create }
        .not_to change { book.read_attribute(:author) }
    end
    specify do
      expect { association.create(name: 'Fred') }
        .to change { book.read_attribute(:author) }.from(nil).to('name' => 'Fred')
    end

    specify do
      expect { existing_association.create }
        .not_to change { existing_book.read_attribute(:author) }
    end
    specify do
      expect { existing_association.create(name: 'Fred') }
        .to change { existing_book.read_attribute(:author) }.from('name' => 'Johny').to('name' => 'Fred')
    end
  end

  describe '#create!' do
    specify { expect { association.create! }.to raise_error ActiveData::ValidationError }

    specify { expect(association.create!(name: 'Fred')).to be_a Author }
    specify { expect(association.create!(name: 'Fred')).to be_persisted }

    specify do
      expect { association.create! rescue nil }
        .not_to change { book.read_attribute(:author) }
    end
    specify do
      expect { association.create! rescue nil }
        .to change { association.reader.try(:attributes) }.from(nil).to('name' => nil)
    end
    specify do
      expect { association.create(name: 'Fred') }
        .to change { book.read_attribute(:author) }.from(nil).to('name' => 'Fred')
    end

    specify do
      expect { existing_association.create! rescue nil }
        .not_to change { existing_book.read_attribute(:author) }
    end
    specify do
      expect { existing_association.create! rescue nil }
        .to change { existing_association.reader.try(:attributes) }.from('name' => 'Johny').to('name' => nil)
    end
    specify do
      expect { existing_association.create!(name: 'Fred') }
        .to change { existing_book.read_attribute(:author) }.from('name' => 'Johny').to('name' => 'Fred')
    end
  end

  describe '#apply_changes' do
    specify { expect { association.build; association.apply_changes }.to change { association.target.try(:persisted?) }.to(false) }
    specify { expect { association.build(name: 'Fred'); association.apply_changes }.to change { association.target.try(:persisted?) }.to(true) }
    specify { expect { existing_association.target.mark_for_destruction; existing_association.apply_changes }.to change { existing_association.target }.to(nil) }
    specify { expect { existing_association.target.destroy!; existing_association.apply_changes }.to change { existing_association.target }.to(nil) }
    specify { expect { existing_association.target.mark_for_destruction; existing_association.apply_changes }.to change { existing_association.destroyed.try(:name) }.from(nil).to('Johny') }
    specify { expect { existing_association.target.destroy!; existing_association.apply_changes }.to change { existing_association.destroyed.try(:name) }.from(nil).to('Johny') }
  end

  describe '#apply_changes!' do
    specify { expect { association.build; association.apply_changes! }.to raise_error ActiveData::AssociationChangesNotApplied }
    specify { expect { association.build(name: 'Fred'); association.apply_changes! }.to change { association.target.try(:persisted?) }.to(true) }
    specify { expect { existing_association.target.mark_for_destruction; existing_association.apply_changes! }.to change { existing_association.target }.to(nil) }
    specify { expect { existing_association.target.destroy!; existing_association.apply_changes! }.to change { existing_association.target }.to(nil) }
  end

  describe '#target' do
    specify { expect(association.target).to be_nil }
    specify { expect(existing_association.target).to eq(existing_book.author) }
    specify { expect { association.build }.to change { association.target }.to(an_instance_of(Author)) }
  end

  describe '#default' do
    before { Book.embeds_one :author, default: -> { { name: 'Default' } } }
    before do
      Author.class_eval do
        include ActiveData::Model::Primary
        primary :name
      end
    end
    let(:new_author) { Author.new.tap { |a| a.name = 'Morty' } }
    let(:existing_book) { Book.instantiate title: 'My Life' }

    specify { expect(association.target.name).to eq('Default') }
    specify { expect(association.target.new_record?).to eq(true) }
    specify { expect { association.replace(new_author) }.to change { association.target.name }.to eq('Morty') }
    specify { expect { association.replace(nil) }.to change { association.target }.to be_nil }

    specify { expect(existing_association.target).to be_nil }
    specify { expect { existing_association.replace(new_author) }.to change { existing_association.target }.to(an_instance_of(Author)) }
    specify { expect { existing_association.replace(nil) }.not_to change { existing_association.target } }

    context do
      before { Author.send(:include, ActiveData::Model::Dirty) }
      specify { expect(association.target).not_to be_changed }
    end
  end

  describe '#loaded?' do
    let(:new_author) { Author.new(name: 'Morty') }

    specify { expect(association.loaded?).to eq(false) }
    specify { expect { association.target }.to change { association.loaded? }.to(true) }
    specify { expect { association.build }.to change { association.loaded? }.to(true) }
    specify { expect { association.replace(new_author) }.to change { association.loaded? }.to(true) }
    specify { expect { association.replace(nil) }.to change { association.loaded? }.to(true) }
    specify { expect { existing_association.replace(new_author) }.to change { existing_association.loaded? }.to(true) }
    specify { expect { existing_association.replace(nil) }.to change { existing_association.loaded? }.to(true) }
  end

  describe '#reload' do
    specify { expect(association.reload).to be_nil }

    specify { expect(existing_association.reload).to be_a Author }
    specify { expect(existing_association.reload).to be_persisted }

    context do
      before { association.build(name: 'Fred') }
      specify do
        expect { association.reload }
          .to change { association.reader.try(:attributes) }.from('name' => 'Fred').to(nil)
      end
    end

    context do
      before { existing_association.build(name: 'Fred') }
      specify do
        expect { existing_association.reload }
          .to change { existing_association.reader.try(:attributes) }
          .from('name' => 'Fred').to('name' => 'Johny')
      end
    end
  end

  describe '#clear' do
    specify { expect(association.clear).to eq(true) }
    specify { expect { association.clear }.not_to change { association.reader } }

    specify { expect(existing_association.clear).to eq(true) }
    specify do
      expect { existing_association.clear }
        .to change { existing_association.reader.try(:attributes) }.from('name' => 'Johny').to(nil)
    end
    specify do
      expect { existing_association.clear }
        .to change { existing_book.read_attribute(:author) }.from('name' => 'Johny').to(nil)
    end

    context do
      before { Author.send(:include, ActiveData::Model::Callbacks) }
      if ActiveModel.version >= Gem::Version.new('5.0.0')
        before { Author.before_destroy { throw :abort } }
      else
        before { Author.before_destroy { false } }
      end
      specify { expect(existing_association.clear).to eq(false) }
      specify do
        expect { existing_association.clear }
          .not_to change { existing_association.reader }
      end
      specify do
        expect { existing_association.clear }
          .not_to change { existing_book.read_attribute(:author).symbolize_keys }
      end
    end
  end

  describe '#reader' do
    specify { expect(association.reader).to be_nil }

    specify { expect(existing_association.reader).to be_a Author }
    specify { expect(existing_association.reader).to be_persisted }

    context do
      before { association.build }
      specify { expect(association.reader).to be_a Author }
      specify { expect(association.reader).not_to be_persisted }
      specify { expect(association.reader(true)).to be_nil }
    end

    context do
      before { existing_association.build(name: 'Fred') }
      specify { expect(existing_association.reader.name).to eq('Fred') }
      specify { expect(existing_association.reader(true).name).to eq('Johny') }
    end
  end

  describe '#writer' do
    let(:new_author) { Author.new(name: 'Morty') }
    let(:invalid_author) { Author.new }

    context 'new owner' do
      let(:book) do
        Book.new.tap do |book|
          book.send(:mark_persisted!)
        end
      end

      specify do
        expect { association.writer(nil) }
          .not_to change { book.read_attribute(:author) }
      end
      specify do
        expect { association.writer(new_author) }
          .to change { association.reader.try(:attributes) }.from(nil).to('name' => 'Morty')
      end
      specify do
        expect { association.writer(new_author) }
          .to change { book.read_attribute(:author) }.from(nil).to('name' => 'Morty')
      end

      specify do
        expect { association.writer(invalid_author) }
          .to raise_error ActiveData::AssociationChangesNotApplied
      end
      specify do
        expect { association.writer(invalid_author) rescue nil }
          .not_to change { association.reader }
      end
      specify do
        expect { association.writer(invalid_author) rescue nil }
          .not_to change { book.read_attribute(:author) }
      end
    end

    context 'persisted owner' do
      specify do
        expect { association.writer(stub_model(:dummy).new) }
          .to raise_error ActiveData::AssociationTypeMismatch
      end

      specify { expect(association.writer(nil)).to be_nil }
      specify { expect(association.writer(new_author)).to eq(new_author) }
      specify do
        expect { association.writer(nil) }
          .not_to change { book.read_attribute(:author) }
      end
      specify do
        expect { association.writer(new_author) }
          .to change { association.reader.try(:attributes) }.from(nil).to('name' => 'Morty')
      end
      specify do
        expect { association.writer(new_author) }
          .not_to change { book.read_attribute(:author) }
      end

      specify do
        expect { association.writer(invalid_author) }
          .to change { association.reader.try(:attributes) }.from(nil).to('name' => nil)
      end
      specify do
        expect { association.writer(invalid_author) }
          .not_to change { book.read_attribute(:author) }
      end

      specify do
        expect { existing_association.writer(stub_model(:dummy).new) rescue nil }
          .not_to change { existing_book.read_attribute(:author) }
      end
      specify do
        expect { existing_association.writer(stub_model(:dummy).new) rescue nil }
          .not_to change { existing_association.reader }
      end

      specify { expect(existing_association.writer(nil)).to be_nil }
      specify { expect(existing_association.writer(new_author)).to eq(new_author) }
      specify do
        expect { existing_association.writer(nil) }
          .to change { existing_book.read_attribute(:author) }.from('name' => 'Johny').to(nil)
      end
      specify do
        expect { existing_association.writer(new_author) }
          .to change { existing_association.reader.try(:attributes) }
          .from('name' => 'Johny').to('name' => 'Morty')
      end
      specify do
        expect { existing_association.writer(new_author) }
          .to change { existing_book.read_attribute(:author) }
          .from('name' => 'Johny').to('name' => 'Morty')
      end

      specify do
        expect { existing_association.writer(invalid_author) }
          .to raise_error ActiveData::AssociationChangesNotApplied
      end
      specify do
        expect { existing_association.writer(invalid_author) rescue nil }
          .not_to change { existing_association.reader }
      end
      specify do
        expect { existing_association.writer(invalid_author) rescue nil }
          .not_to change { existing_book.read_attribute(:author) }
      end
    end
  end
end
