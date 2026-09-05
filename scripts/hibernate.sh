#!/bin/bash
set -e
REGION="us-east-2"
CLUSTER_NAME="cnoe-ref-impl"
echo "⏸️  Hibernating cluster $CLUSTER_NAME (scaling worker nodes to 0)..."
NODEGROUP=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query "nodegroups[0]" --output text)
if [ -n "$NODEGROUP" ] && [ "$NODEGROUP" != "None" ]; then
    aws eks update-nodegroup-config \
        --cluster-name $CLUSTER_NAME \
        --nodegroup-name $NODEGROUP \
        --scaling-config minSize=0,desiredSize=0 \
        --region $REGION
    echo "✅ Nodegroup $NODEGROUP scaled to 0 nodes. Compute billing paused."
else
    echo "⚠️ No nodegroup found for $CLUSTER_NAME."
fi
