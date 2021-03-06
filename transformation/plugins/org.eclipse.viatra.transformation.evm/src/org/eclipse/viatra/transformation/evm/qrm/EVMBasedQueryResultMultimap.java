/*******************************************************************************
 * Copyright (c) 2010-2012, Abel Hegedus, Istvan Rath and Daniel Varro
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Abel Hegedus - initial API and implementation
 *******************************************************************************/
package org.eclipse.viatra.transformation.evm.qrm;

import java.util.HashSet;
import java.util.Set;

import org.apache.log4j.Logger;
import org.eclipse.viatra.query.runtime.api.IMatchProcessor;
import org.eclipse.viatra.query.runtime.api.IPatternMatch;
import org.eclipse.viatra.query.runtime.api.IQuerySpecification;
import org.eclipse.viatra.query.runtime.api.ViatraQueryEngine;
import org.eclipse.viatra.query.runtime.api.ViatraQueryMatcher;
import org.eclipse.viatra.query.runtime.base.api.QueryResultMultimap;
import org.eclipse.viatra.transformation.evm.api.ExecutionSchema;
import org.eclipse.viatra.transformation.evm.api.Job;
import org.eclipse.viatra.transformation.evm.specific.ExecutionSchemas;
import org.eclipse.viatra.transformation.evm.specific.Lifecycles;
import org.eclipse.viatra.transformation.evm.specific.Rules;
import org.eclipse.viatra.transformation.evm.specific.Schedulers;
import org.eclipse.viatra.transformation.evm.specific.event.IncQueryActivationStateEnum;
import org.eclipse.viatra.transformation.evm.specific.job.StatelessJob;

/**
 * This {@link QueryResultMultimap} implementation uses the EVM to provide a query-based multimap.
 * 
 * The contents of the multimap will be updated when the activations are fired in the EVM.
 * 
 * @author Abel Hegedus
 * 
 */
public abstract class EVMBasedQueryResultMultimap<Match extends IPatternMatch, KeyType, ValueType> extends
        QueryResultMultimap<KeyType, ValueType> {

    private final Set<Job<Match>> jobs;

    private final ExecutionSchema schema;

    /**
     * Creates a multimap on top of the given execution schema.
     * 
     * @param schema
     */
    protected EVMBasedQueryResultMultimap(final ExecutionSchema schema) {
        super(Logger.getLogger(EVMBasedQueryResultMultimap.class));
        this.schema = schema;
        this.jobs = new HashSet<Job<Match>>();
        jobs.add(new StatelessJob<Match>(IncQueryActivationStateEnum.APPEARED, new IMatchProcessor<Match>() {
            @Override
            public void process(final Match match) {
                KeyType key = getKeyFromMatch(match);
                ValueType value = getValueFromMatch(match);
                internalPut(key, value);
            }
        }));

        jobs.add(new StatelessJob<Match>(IncQueryActivationStateEnum.DISAPPEARED, new IMatchProcessor<Match>() {
            @Override
            public void process(final Match match) {
                KeyType key = getKeyFromMatch(match);
                ValueType value = getValueFromMatch(match);
                internalRemove(key, value);
            }
        }));
    }

    /**
     * Creates a new multimap on the given engine. It will use an execution schema that
     * is scheduled with IQBase update callbacks.
     * 
     */
    protected EVMBasedQueryResultMultimap(final ViatraQueryEngine engine) {
        this(ExecutionSchemas.createIncQueryExecutionSchema(engine,
                Schedulers.getQueryEngineSchedulerFactory(engine)));
    }

    /**
     * Adds the given query into the results of the multimap. 
     * 
     * @param querySpecification
     */
    public <Matcher extends ViatraQueryMatcher<Match>> void addMatcherToMultimapResults(
            final IQuerySpecification<Matcher> querySpecification) {
        schema.addRule(Rules.newMatcherRuleSpecification(querySpecification,
                Lifecycles.getDefault(false, true), jobs));
    }

    /**
     * Processes the given match and returns the key to be used in the multimap.
     * 
     * @param match
     * @return the computed key
     */
    protected abstract KeyType getKeyFromMatch(final Match match);

    /**
     * Processes the given match and returns the value to be used in the mulitmap.
     * 
     * @param match
     * @return the computed value
     */
    protected abstract ValueType getValueFromMatch(final Match match);

}
