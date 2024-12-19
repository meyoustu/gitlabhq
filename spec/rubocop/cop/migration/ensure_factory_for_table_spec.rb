# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../rubocop/cop/migration/ensure_factory_for_table'

RSpec.describe RuboCop::Cop::Migration::EnsureFactoryForTable, feature_category: :database do
  context 'with faked factories' do
    let(:ee) { true }

    before do
      allow(described_class).to receive(:factories).and_return(factories)
      allow(cop).to receive(:ee?).and_return(ee)
    end

    context 'without matching factories' do
      let(:factories) { [] }

      it 'registers an offense when a table does not have a corresponding factory' do
        expect_offense(<<~RUBY)
        create_table :users do |t|
                     ^^^^^^ No factory found for the table `users`.
          t.string :name
          t.timestamps
        end

        create_table "users" do |t|
                     ^^^^^^^ No factory found for the table `users`.
          t.string :name
          t.timestamps
        end
        RUBY
      end

      it 'does not register an offense for non-string and non-symbol table name' do
        expect_no_offenses(<<~RUBY)
        TABLE = :users

        create_table TABLE do |t|
          t.string :name
          t.timestamps
        end
        RUBY
      end

      context 'when non-EE' do
        let(:ee) { false }

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
          create_table :users do |t|
            t.string :name
            t.timestamps
          end
          RUBY
        end

        context 'with rubocop:disable comment' do
          let(:source) do
            <<~RUBY
              create_table :users do |t| # rubocop:disable Migration/EnsureFactoryForTable  -- Some reason
                t.string :name
                t.timestamps
              end
            RUBY
          end

          it 'adds a disabled offense for Migration/EnsureFactoryForTable to avoid Lint/RedundantCopDisableDirective' do
            # rubocop:disable InternalAffairs/DeprecateCopHelper -- Can't use methods from RuboCop::RSpec::ExpectOffense
            # here as they remove the disabled offenses.
            processed_source = parse_source(source)
            # rubocop:enable InternalAffairs/DeprecateCopHelper

            team = RuboCop::Cop::Team.new([cop], configuration, raise_error: true)

            offenses = team.investigate(processed_source).offenses
            offense = offenses.first
            expect(offenses.size).to eq(1)
            expect(offense.cop_name).to eq(cop.name)
            expect(offense.status).to eq(:disabled)
          end
        end
      end
    end

    context 'with matching factories' do
      let(:factories) { ['spec/factories/users.rb'] }

      it 'does not register an offense when a table has a corresponding factory' do
        expect_no_offenses(<<~RUBY)
        create_table :users do |t|
          t.string :name
          t.timestamps
        end
        RUBY
      end
    end
  end

  describe '.factories' do
    subject { described_class.factories }

    it { is_expected.not_to be_empty }
  end
end
